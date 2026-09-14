import CryptoKit
import Foundation

enum SecureCrypto {
    static let suite = HPKE.Ciphersuite.P256_SHA256_AES_GCM_256

    static func decode(_ value: String) throws -> Data {
        guard let data = Data(base64Encoded: value) else { throw SecureFailure.invalid }
        return data
    }

    static func fingerprint(_ key: String) -> String {
        guard let data = Data(base64Encoded: key) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func pairingCode(user: String, device: String, publicKey: String, identity: String) -> String {
        let data = Data("pushnow-pairing-v1\n\(user)\n\(device)\n\(publicKey)\n\(identity)".utf8)
        let hex = SHA256.hash(data: data).prefix(8).map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { offset in
            String(hex.dropFirst(offset).prefix(4))
        }.joined(separator: "-")
    }

    static func text(_ kind: String, user: String, id: String, key: String) -> Data {
        Data("pushnow-\(kind)-v1\n\(user)\n\(id)\n\(key)".utf8)
    }

    static func sign(_ data: Data, privateKey: Data) throws -> String {
        try P256.Signing.PrivateKey(rawRepresentation: privateKey)
            .signature(for: data).rawRepresentation.base64EncodedString()
    }

    static func verify(_ signature: String, data: Data, identity: String) throws {
        let key = try P256.Signing.PublicKey(x963Representation: decode(identity))
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: decode(signature))
        guard key.isValidSignature(signature, for: data) else { throw SecureFailure.invalid }
    }

    static func decrypt(_ message: SecureMessage, keys: SecureLocalKeys) throws -> SecurePlaintext {
        guard message.userId == keys.userId, message.deviceId == keys.deviceId,
              let identity = keys.identityPublicKey,
              let expiry = date(message.expiresAt), expiry > Date() else { throw SecureFailure.invalid }
        try verify(message.sourceCertificate,
                   data: text("source", user: message.userId, id: message.sourceId, key: message.sourcePublicKey),
                   identity: identity)
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: keys.privateKey)
        let senderKey = try P256.KeyAgreement.PublicKey(x963Representation: decode(message.sourcePublicKey))
        var recipient = try HPKE.Recipient(privateKey: privateKey, ciphersuite: suite,
            info: Data("pushnow-message-v1".utf8), encapsulatedKey: decode(message.enc), authenticatedBy: senderKey)
        let aad = Data("pushnow-message-v1\n\(message.userId)\n\(message.sourceId)\n\(message.deviceId)\n\(message.messageId)\n\(message.expiresAt)".utf8)
        let clear = try recipient.open(decode(message.ciphertext), authenticating: aad)
        return try JSONDecoder().decode(SecurePlaintext.self, from: clear)
    }

    static func approval(for device: SecureDevice, identityPrivateKey: Data, archive: SecureArchiveKeys? = nil) throws -> SecureApproval {
        let publicKey = try P256.KeyAgreement.PublicKey(x963Representation: decode(device.publicKey))
        var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: suite, info: Data("pushnow-approval-v1".utf8))
        var payload = ["identity_private_key": identityPrivateKey.base64EncodedString()]
        if let archive {
            payload["archive_id"] = archive.archive.id
            payload["archive_private_key"] = archive.privateKey.base64EncodedString()
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let ciphertext = try sender.seal(data, authenticating: text("approval", user: device.userId, id: device.id, key: device.publicKey))
        return SecureApproval(enc: sender.encapsulatedKey.base64EncodedString(), ciphertext: ciphertext.base64EncodedString())
    }

    static func accept(_ approval: SecureApproval, device: SecureDevice, keys: SecureLocalKeys, identity: String) throws -> SecureLocalKeys {
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: keys.privateKey)
        var recipient = try HPKE.Recipient(privateKey: privateKey, ciphersuite: suite,
            info: Data("pushnow-approval-v1".utf8), encapsulatedKey: decode(approval.enc))
        let data = try recipient.open(decode(approval.ciphertext),
            authenticating: text("approval", user: keys.userId, id: keys.deviceId, key: device.publicKey))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let secret = json["identity_private_key"], let certificate = device.certificate else { throw SecureFailure.invalid }
        let identityKey = try P256.Signing.PrivateKey(rawRepresentation: decode(secret))
        guard identityKey.publicKey.x963Representation.base64EncodedString() == identity else { throw SecureFailure.invalid }
        try verify(certificate, data: text("device", user: keys.userId, id: keys.deviceId, key: device.publicKey), identity: identity)
        var result = keys
        result.identityPublicKey = identity
        result.identityPrivateKey = identityKey.rawRepresentation
        result.identityEstablished = true
        if let archiveId = json["archive_id"], let archiveKey = json["archive_private_key"] {
            result.archiveTransfer = SecureArchiveTransfer(archiveId: archiveId, archivePrivateKey: archiveKey)
        }
        return result
    }

    static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
