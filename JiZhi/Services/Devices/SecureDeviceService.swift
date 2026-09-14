import CryptoKit
import Foundation
import Observation
import UIKit

@MainActor @Observable
final class SecureDeviceService {
    let api: APIClient
    let auth: AuthService
    let store = SecureKeyStore()
    var devices: [SecureDevice] = []
    var keys: SecureLocalKeys?
    var proposedIdentity: String?
    var error: String?
    var historyAccessPending = false
    @ObservationIgnored private var enrollment: Task<Void, Error>?
    @ObservationIgnored private var supportsMetadata = true

    init(api: APIClient, auth: AuthService) { self.api = api; self.auth = auth }
    var currentID: String? { keys?.deviceId }
    var trusted: Bool { keys?.identityPrivateKey != nil && keys?.userId == auth.session?.userID && auth.isVerified }
    var fingerprint: String {
        guard let keys, let key = try? P256.KeyAgreement.PrivateKey(rawRepresentation: keys.privateKey) else { return "" }
        return SecureCrypto.fingerprint(key.publicKey.x963Representation.base64EncodedString())
    }
    var pairingCode: String {
        guard let local = keys, let identity = proposedIdentity,
              let key = try? P256.KeyAgreement.PrivateKey(rawRepresentation: local.privateKey) else { return "" }
        return SecureCrypto.pairingCode(user: local.userId, device: local.deviceId,
            publicKey: key.publicKey.x963Representation.base64EncodedString(), identity: identity)
    }

    func enroll() async throws {
        if let enrollment { return try await enrollment.value }
        let task = Task { try await performEnrollment() }
        enrollment = task
        defer { enrollment = nil }
        try await task.value
    }

    private func performEnrollment() async throws {
        guard let user = auth.session?.userID else { throw SecureFailure.invalid }
        let token = try await auth.requireAccessToken()
        let generation = auth.generation
        let directory: SecureDirectory = try await api.getJSON("/v1/secure/devices", accessToken: token)
        guard auth.generation == generation, auth.session?.userID == user else { throw SecureFailure.invalid }
        var local = try store.load(user: user) ?? SecureLocalKeys(userId: user, deviceId: UUID().uuidString.lowercased(),
            privateKey: P256.KeyAgreement.PrivateKey().rawRepresentation)
        if directory.devices.contains(where: { $0.id == local.deviceId && $0.status == "revoked" }) {
            local = SecureLocalKeys(userId: user, deviceId: UUID().uuidString.lowercased(),
                privateKey: P256.KeyAgreement.PrivateKey().rawRepresentation,
                identityPublicKey: local.identityPublicKey, identityPrivateKey: nil)
            try store.activate(nil)
        }
        let agreement = try P256.KeyAgreement.PrivateKey(rawRepresentation: local.privateKey)
        let publicKey = agreement.publicKey.x963Representation.base64EncodedString()
        if local.identityPrivateKey == nil, let identity = directory.identityPublicKey {
            let account = "pairing-root:\(user):\(local.deviceId)"
            if let pinned = try store.read(account), pinned != Data(identity.utf8) { throw SecureFailure.invalid }
            try store.write(Data(identity.utf8), account: account)
        }
        var certificate: String?
        if directory.identityPublicKey == nil {
            let identity = try local.identityPrivateKey.map { try P256.Signing.PrivateKey(rawRepresentation: $0) } ?? P256.Signing.PrivateKey()
            local.identityPrivateKey = identity.rawRepresentation
            local.identityPublicKey = identity.publicKey.x963Representation.base64EncodedString()
            if local.identityEstablished == nil { local.identityEstablished = false }
            certificate = try SecureCrypto.sign(SecureCrypto.text("device", user: user, id: local.deviceId, key: publicKey), privateKey: identity.rawRepresentation)
        } else if let pinned = local.identityPublicKey, pinned != directory.identityPublicKey {
            guard local.identityEstablished == false else { throw SecureFailure.invalid }
            local.identityPrivateKey = nil
            local.identityPublicKey = nil
        }
        try store.save(local)
        keys = local
        let challenge: DeviceChallenge = try await api.getJSON("/v1/secure/device-challenge", accessToken: token)
        guard auth.generation == generation, auth.session?.userID == user else { throw SecureFailure.invalid }
        let proofData = SecureCrypto.text("register", user: user, id: local.deviceId, key: publicKey) + Data("\n\(challenge.challenge)".utf8)
        let proof = try SecureCrypto.sign(proofData, privateKey: local.privateKey)
        let name = DeviceDisplayName.current(existingName: directory.devices.first(where: { $0.id == local.deviceId })?.name,
            installationID: local.deviceId)
        var registration = DeviceRegistration(deviceId: local.deviceId, name: name, platform: "ios", publicKey: publicKey,
                proof: proof, challenge: challenge.challenge, identityPublicKey: certificate == nil ? nil : local.identityPublicKey, certificate: certificate,
                systemVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                model: UIDevice.current.model)
        if !supportsMetadata {
            registration.systemVersion = nil
            registration.appVersion = nil
            registration.model = nil
        }
        let response: DeviceRegistrationResponse
        do {
            response = try await api.postJSON("/v1/secure/devices", body: registration, accessToken: token)
        } catch let error as APIStatusError where error.statusCode == 400 && error.code == "unexpected_field" {
            // Older servers reject optional metadata. Keep the full signed registration protocol.
            guard auth.generation == generation, auth.session?.userID == user else { throw SecureFailure.invalid }
            let fresh: DeviceChallenge = try await api.getJSON("/v1/secure/device-challenge", accessToken: token)
            guard auth.generation == generation, auth.session?.userID == user else { throw SecureFailure.invalid }
            registration.systemVersion = nil
            registration.appVersion = nil
            registration.model = nil
            registration.challenge = fresh.challenge
            registration.proof = try SecureCrypto.sign(
                SecureCrypto.text("register", user: user, id: local.deviceId, key: publicKey)
                    + Data("\n\(fresh.challenge)".utf8), privateKey: local.privateKey)
            response = try await api.postJSON("/v1/secure/devices", body: registration, accessToken: token)
            supportsMetadata = false
        }
        guard auth.generation == generation, auth.session?.userID == user else { throw SecureFailure.invalid }
        proposedIdentity = response.identityPublicKey
        if response.device.status == "active", local.identityPrivateKey != nil, let pinned = local.identityPublicKey, let certificate = response.device.certificate {
            try SecureCrypto.verify(certificate, data: SecureCrypto.text("device", user: user, id: local.deviceId, key: publicKey), identity: pinned)
            local.identityEstablished = true
            try store.save(local)
            keys = local
            try store.activate(user)
        } else { try store.activate(nil) }
        devices = directory.devices.filter { $0.id != response.device.id } + [response.device]
        if response.device.status == "active", local.identityPrivateKey == nil,
           let pinned = try store.read("pairing-root:\(user):\(local.deviceId)"),
           String(data: pinned, encoding: .utf8) == response.identityPublicKey {
            try await acceptApproval(fingerprint: SecureCrypto.fingerprint(response.identityPublicKey))
            _ = try await SecureArchiveService.ensure(service: self)
        }
    }

    func refresh() async {
        do { try await enroll(); error = nil } catch { self.error = AppError(error).localizedDescription }
    }

    func acceptApproval(fingerprint: String) async throws {
        let generation = auth.generation
        guard let keys, let identity = proposedIdentity,
              fingerprint.lowercased() == SecureCrypto.fingerprint(identity),
              let device = devices.first(where: { $0.id == keys.deviceId && $0.status == "active" }) else { throw SecureFailure.invalid }
        let result: ApprovalResponse = try await api.getJSON("/v1/secure/devices/\(keys.deviceId)/approval", accessToken: await auth.requireAccessToken())
        guard auth.generation == generation, auth.session?.userID == keys.userId else { throw SecureFailure.invalid }
        guard let approval = result.approval else { throw SecureFailure.pending }
        let updated = try SecureCrypto.accept(approval, device: device, keys: keys, identity: identity)
        try store.save(updated)
        self.keys = updated
        try store.activate(updated.userId)
    }

    func approve(_ device: SecureDevice, fingerprint: String) async throws {
        guard fingerprint.lowercased() == SecureCrypto.fingerprint(device.publicKey), let secret = keys?.identityPrivateKey else { throw SecureFailure.invalid }
        let archive = try await SecureArchiveService.ensure(service: self)
        let certificate = try SecureCrypto.sign(SecureCrypto.text("device", user: device.userId, id: device.id, key: device.publicKey), privateKey: secret)
        try await api.postJSONNoResponse("/v1/secure/devices/\(device.id)/approve",
            body: DeviceApprovalRequest(certificate: certificate, approval: SecureCrypto.approval(for: device, identityPrivateKey: secret, archive: archive)),
            accessToken: await auth.requireAccessToken())
        await refresh()
    }

    func approvePairing(_ device: SecureDevice, code: String) async throws {
        guard let identity = keys?.identityPublicKey, device.userId == keys?.userId else { throw SecureFailure.invalid }
        let expected = SecureCrypto.pairingCode(user: device.userId, device: device.id,
            publicKey: device.publicKey, identity: identity)
        let normalize: (String) -> String = { $0.uppercased().filter { $0.isHexDigit } }
        guard normalize(code).count == 16, normalize(code) == normalize(expected) else { throw SecureFailure.invalid }
        try await approve(device, fingerprint: SecureCrypto.fingerprint(device.publicKey))
    }

    func update(_ device: SecureDevice, name: String? = nil, enabled: Bool? = nil) async throws {
        let _: DeviceResponse = try await api.patchJSON("/v1/secure/devices/\(device.id)",
            body: DeviceUpdate(name: name, notificationsEnabled: enabled), accessToken: await auth.requireAccessToken())
        await refresh()
    }

}

struct DeviceRegistration: Encodable {
    var deviceId: String; var name: String; var platform: String; var publicKey: String
    var proof: String; var challenge: String; var identityPublicKey: String?; var certificate: String?
    var systemVersion: String? = nil
    var appVersion: String? = nil
    var model: String? = nil
}
struct DeviceChallenge: Decodable { var challenge: String }
struct DeviceRegistrationResponse: Decodable { var device: SecureDevice; var identityPublicKey: String }
struct DeviceResponse: Decodable { var device: SecureDevice }
struct ApprovalResponse: Decodable { var approval: SecureApproval? }
struct DeviceApprovalRequest: Encodable { var certificate: String; var approval: SecureApproval }
struct DeviceUpdate: Encodable { var name: String?; var notificationsEnabled: Bool? }
