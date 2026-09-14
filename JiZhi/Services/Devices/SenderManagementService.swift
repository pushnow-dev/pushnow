import Foundation
import Observation

enum SenderKeyExpiry: Int, CaseIterable, Identifiable {
    case never = 0, sevenDays = 7, thirtyDays = 30, ninetyDays = 90
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .never: "Never"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        }
    }
    var expiresAt: String? {
        guard rawValue > 0 else { return nil }
        return Date().addingTimeInterval(Double(rawValue) * 86_400).ISO8601Format()
    }
}

struct SenderKey: Decodable, Identifiable {
    var id: String
    var sourceId: String
    var sourceName: String?
    var keyPrefix: String
    var createdAt: String
    var expiresAt: String?
    var lastUsedAt: String?
    var revokedAt: String?
    var expired: Bool { expiresAt.flatMap(SecureCrypto.date).map { $0 <= Date() } ?? false }
    var state: String { revokedAt != nil ? "Revoked" : expired ? "Expired" : "Active" }
}

struct SenderNotificationLog: Decodable, Identifiable {
    var messageId: String
    var sourceId: String
    var keyId: String?
    var sourceName: String?
    var createdAt: String
    var scheduledAt: String?
    var expiresAt: String?
    var readAt: String?
    var deliveries: [SenderDeliveryLog]
    var id: String { messageId }
}

struct SenderDeliveryLog: Decodable, Identifiable {
    var deviceId: String
    var deviceName: String?
    var status: String
    var lastError: String?
    var attempts: Int
    var acceptedAt: String?
    var id: String { deviceId }
}

struct SenderKeySecret: Identifiable {
    let id = UUID()
    let value: String
}

// Each screen owns an instance; no credentials are persisted or shared between screens.
@MainActor @Observable
final class SenderManagementService {
    private(set) var keys: [SenderKey] = []
    private(set) var logs: [SenderNotificationLog] = []
    private(set) var nextCursor: String?
    private(set) var busy = false
    private(set) var loaded = false
    private(set) var retryMore = false
    var error: String?
    var secret: SenderKeySecret?
    @ObservationIgnored private var generation: UUID?

    func clear() {
        keys = []; logs = []; nextCursor = nil; secret = nil
        error = nil; loaded = false; generation = nil; retryMore = false
    }

    func loadKeys(device: SecureDeviceService) async {
        await perform(device: device) { token in
            let response: KeysResponse = try await device.api.getJSON("/v2/keys", accessToken: token)
            try self.validate(device)
            self.keys = response.keys
            self.loaded = true
        }
    }

    func update(_ key: SenderKey, expiry: SenderKeyExpiry, device: SecureDeviceService) async -> Bool {
        await perform(device: device) { token in
            let _: EmptyResponse = try await device.api.patchJSON("/v2/keys/\(try self.pathID(key.id))",
                body: ExpiryBody(expiresAt: expiry.expiresAt), accessToken: token)
            try self.validate(device)
            let response: KeysResponse = try await device.api.getJSON("/v2/keys", accessToken: token)
            try self.validate(device)
            self.keys = response.keys
        }
    }

    func revoke(_ key: SenderKey, device: SecureDeviceService) async {
        await perform(device: device) { token in
            try await device.api.deleteNoResponse("/v2/keys/\(try self.pathID(key.id))", accessToken: token)
            try self.validate(device)
            if let index = self.keys.firstIndex(where: { $0.id == key.id }) {
                self.keys[index].revokedAt = Date().ISO8601Format()
            }
        }
    }

    func create(sourceId: String, expiry: SenderKeyExpiry, device: SecureDeviceService) async -> Bool {
        await perform(device: device) { token in
            let response: CreatedKeyResponse = try await device.api.postJSON(
                "/v1/sources/\(try self.pathID(sourceId))/keys",
                body: ExpiryBody(expiresAt: expiry.expiresAt), accessToken: token)
            try self.validate(device)
            var key = response.key
            key.sourceName = key.sourceName ?? self.keys.first(where: { $0.sourceId == sourceId })?.sourceName
            self.keys.removeAll { $0.id == key.id }
            self.keys.insert(key, at: 0)
            self.secret = SenderKeySecret(value: response.sourceKey)
        }
    }

    func loadLogs(device: SecureDeviceService, keyId: String?, more: Bool = false) async {
        guard !more || nextCursor != nil else { return }
        await perform(device: device) { token in
            self.retryMore = more
            var query = URLComponents()
            query.path = "/v2/logs"
            query.queryItems = [URLQueryItem(name: "limit", value: "30")]
            if let keyId { query.queryItems?.append(URLQueryItem(name: "key_id", value: keyId)) }
            if more, let cursor = self.nextCursor {
                query.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
            }
            guard let path = query.string else { throw SecureFailure.invalid }
            let response: LogsResponse = try await device.api.getJSON(path, accessToken: token)
            try self.validate(device)
            if more {
                let existing = Set(self.logs.map(\.id))
                self.logs += response.logs.filter { !existing.contains($0.id) }
            } else { self.logs = response.logs }
            self.nextCursor = response.nextCursor
            self.loaded = true
        }
    }

    private func validate(_ device: SecureDeviceService) throws {
        guard generation == device.auth.generation, !Task.isCancelled else { throw CancellationError() }
    }

    private func pathID(_ value: String) throws -> String {
        guard UUID(uuidString: value) != nil else {
            throw SecureFailure.invalid
        }
        return value
    }

    @discardableResult
    private func perform(device: SecureDeviceService, action: (String) async throws -> Void) async -> Bool {
        guard !busy else { return false }
        if generation != device.auth.generation { clear(); generation = device.auth.generation }
        let epoch = device.auth.generation
        busy = true; error = nil
        defer { busy = false }
        do {
            let token = try await device.auth.requireAccessToken()
            try validate(device)
            try await action(token)
            try validate(device)
            return true
        } catch {
            if epoch != device.auth.generation { clear() }
            else if !(error is CancellationError) { self.error = AppError(error).localizedDescription }
            return false
        }
    }
}

private struct KeysResponse: Decodable { var keys: [SenderKey] }
private struct LogsResponse: Decodable { var logs: [SenderNotificationLog]; var nextCursor: String? }
private struct CreatedKeyResponse: Decodable { var sourceKey: String; var key: SenderKey }
private struct EmptyResponse: Decodable {}
private struct ExpiryBody: Encodable {
    var expiresAt: String?
    enum CodingKeys: String, CodingKey { case expiresAt }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let expiresAt { try container.encode(expiresAt, forKey: .expiresAt) }
        else { try container.encodeNil(forKey: .expiresAt) }
    }
}
