import CryptoKit
import Foundation
import Observation

@MainActor @Observable
final class SecureSourceService {
    var configuration: String?
    var error: String?
    var busy = false

    func create(name: String, service: SecureDeviceService, environment: AppEnvironment) async {
        busy = true
        defer { busy = false }
        do {
            let generation = service.auth.generation
            guard let keys = service.keys, let identity = keys.identityPublicKey,
                  let secret = keys.identityPrivateKey else { throw SecureFailure.pending }
            let credential = try await environment.repository.createSource(SourceCreationInput(name: name,
                sourceType: .agent, defaultPriority: "normal", defaultPushEnabled: true))
            guard service.auth.generation == generation else { throw SecureFailure.invalid }
            let sender = P256.KeyAgreement.PrivateKey()
            let publicKey = sender.publicKey.x963Representation.base64EncodedString()
            let certificate = try SecureCrypto.sign(SecureCrypto.text("source", user: keys.userId,
                id: credential.source.id, key: publicKey), privateKey: secret)
            let _: SecureSourceResponse = try await service.api.putJSON("/v1/secure/sources/\(credential.source.id)",
                body: SecureSourceRequest(publicKey: publicKey, certificate: certificate), accessToken: await service.auth.requireAccessToken())
            guard service.auth.generation == generation else { throw SecureFailure.invalid }
            let payload = ["api_url": environment.configuration.apiBaseURL.absoluteString,
                "user_id": keys.userId, "source_id": credential.source.id, "source_key": credential.sourceKey,
                "identity_public_key": identity, "sender_private_key": sender.rawRepresentation.base64EncodedString()]
            configuration = String(data: try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)
        } catch { self.error = AppError(error).localizedDescription }
    }
}

private struct SecureSourceRequest: Encodable { var publicKey: String; var certificate: String }
private struct SecureSourceResponse: Decodable {}
