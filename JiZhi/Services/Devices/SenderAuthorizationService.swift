import Foundation
import Observation

struct SenderAuthorization: Decodable {
    var id: String
    var name: String
    var publicKey: String
    var expiresAt: String
}
struct AuthorizedSender: Decodable, Identifiable {
    var id: String
    var name: String
    var publicKey: String
    var createdAt: String
    var status: String
}

@MainActor @Observable
final class SenderAuthorizationService {
    @ObservationIgnored private let prepareArchive: @MainActor (SecureDeviceService) async throws -> Void
    var authorization: SenderAuthorization?
    var senders: [AuthorizedSender] = []
    var busy = false
    var error: String?
    var approved = false

    init(prepareArchive: @escaping @MainActor (SecureDeviceService) async throws -> Void = {
        _ = try await SecureArchiveService.ensure(service: $0)
    }) {
        self.prepareArchive = prepareArchive
    }

    func lookup(code: String, device: SecureDeviceService) async {
        await perform {
            self.authorization = nil
            self.approved = false
            let normalized = code.uppercased().filter { $0.isASCII && $0.isLetter || $0.isNumber }
            guard normalized.count == 8 else { throw SecureFailure.invalid }
            let epoch = device.auth.generation
            try await self.prepareArchive(device)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let token = try await device.auth.requireAccessToken()
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let result: LookupResponse = try await device.api.getJSON("/v2/authorizations/lookup?code=\(normalized)",
                accessToken: token)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            self.authorization = result.authorization
            self.approved = false
        }
    }

    func approve(device: SecureDeviceService, environment: AppEnvironment, confirmed: Bool, expiresAt: String? = nil) async {
        await perform {
            let epoch = device.auth.generation
            if let expiresAt {
                guard let date = SecureCrypto.date(expiresAt), date > Date() else { throw SecureFailure.invalid }
            }
            guard confirmed, let request = self.authorization,
                  let expiry = SecureCrypto.date(request.expiresAt), expiry > Date(),
                  let local = device.keys, let secret = local.identityPrivateKey,
                  let identity = local.identityPublicKey else { throw SecureFailure.invalid }
            let archive = try await SecureArchiveService.ensure(service: device)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let credential = try await environment.repository.createSource(SourceCreationInput(name: request.name,
                sourceType: .agent, defaultPriority: "normal", defaultPushEnabled: true))
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let certificate = try SecureCrypto.sign(SecureCrypto.text("source", user: local.userId,
                id: credential.source.id, key: request.publicKey), privateKey: secret)
            let token = try await device.auth.requireAccessToken()
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let _: SourceSetupResponse = try await device.api.putJSON("/v1/secure/sources/\(credential.source.id)",
                body: SourceSetup(publicKey: request.publicKey, certificate: certificate), accessToken: token)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let payload = SenderGrant(apiUrl: environment.configuration.apiBaseURL.absoluteString, userId: local.userId,
                sourceId: credential.source.id, sourceKey: credential.sourceKey, identityPublicKey: identity, archive: archive.archive)
            let grant = try SecureV2Crypto.sealGrant(payload, publicKey: request.publicKey, info: "pushnow-sender-grant-v2",
                aad: SecureV2Crypto.aad([2, "sender-grant", request.id, request.publicKey]))
            try await device.api.postJSONNoResponse("/v2/authorizations/\(request.id)/approve",
                body: SenderApproval(sourceId: credential.source.id, enc: grant.enc, ciphertext: grant.ciphertext, expiresAt: expiresAt),
                accessToken: token)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            self.approved = true
            self.authorization = nil
        }
        if approved { await refresh(device: device) }
    }

    func monitorAccountRequests(environment: AppEnvironment) async {
        let device = environment.authService.secureDevices(
            api: APIClient(baseURL: environment.configuration.apiBaseURL))
        do {
            try await device.enroll()
            guard device.trusted else { return }
            _ = try await SecureArchiveService.ensure(service: device)
        } catch { return }
        let epoch = device.auth.generation
        while !Task.isCancelled, epoch == device.auth.generation, device.trusted {
            await approveAccountRequests(device: device, environment: environment)
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
        }
    }

    // Only account-bound requests returned by this authenticated endpoint are automatic.
    // Legacy short-code requests continue to require explicit confirmation.
    func approveAccountRequests(device: SecureDeviceService, environment: AppEnvironment) async {
        guard device.trusted, !busy else { return }
        let epoch = device.auth.generation
        do {
            let token = try await device.auth.requireAccessToken()
            let pending: AccountRequests = try await device.api.getJSON(
                "/v2/account-authorizations/pending", accessToken: token)
            guard epoch == device.auth.generation else { return }
            for request in pending.authorizations {
                guard !Task.isCancelled, epoch == device.auth.generation, device.trusted else { return }
                authorization = request
                await approve(device: device, environment: environment, confirmed: true)
            }
        } catch { self.error = AppError(error).localizedDescription }
    }

    func refresh(device: SecureDeviceService) async {
        await perform {
            let epoch = device.auth.generation
            let token = try await device.auth.requireAccessToken()
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            let result: SenderResponse = try await device.api.getJSON("/v2/senders", accessToken: token)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            self.senders = result.senders
        }
    }

    func revoke(_ sender: AuthorizedSender, device: SecureDeviceService) async {
        await perform {
            let epoch = device.auth.generation
            let token = try await device.auth.requireAccessToken()
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
            try await device.api.deleteNoResponse("/v2/senders/\(sender.id)", accessToken: token)
            guard epoch == device.auth.generation else { throw SecureFailure.invalid }
        }
        await refresh(device: device)
    }

    private func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do { try await action(); error = nil } catch { self.error = AppError(error).localizedDescription }
    }
}

private struct LookupResponse: Decodable { var authorization: SenderAuthorization; var archive: SecureArchive? }
private struct SenderResponse: Decodable { var senders: [AuthorizedSender] }
private struct SourceSetup: Encodable { var publicKey: String; var certificate: String }
private struct SourceSetupResponse: Decodable {}
private struct SenderGrant: Encodable {
    var apiUrl: String; var userId: String; var sourceId: String; var sourceKey: String
    var identityPublicKey: String; var archive: SecureArchive
}
private struct SenderApproval: Encodable {
    var sourceId: String
    var enc: String
    var ciphertext: String
    var expiresAt: String?
    enum CodingKeys: String, CodingKey { case sourceId, enc, ciphertext, expiresAt }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceId, forKey: .sourceId)
        try container.encode(enc, forKey: .enc)
        try container.encode(ciphertext, forKey: .ciphertext)
        if let expiresAt { try container.encode(expiresAt, forKey: .expiresAt) }
        else { try container.encodeNil(forKey: .expiresAt) }
    }
}

private struct AccountRequests: Decodable { var authorizations: [SenderAuthorization] }
