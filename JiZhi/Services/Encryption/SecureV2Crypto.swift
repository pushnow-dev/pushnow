import CryptoKit
import Foundation

enum SecureV2Crypto {
    static func aad(_ values: [Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: values, options: [.withoutEscapingSlashes])
    }

    static func verify(_ archive: SecureArchive, user: String, identity: String) throws {
        try SecureCrypto.verify(archive.certificate,
            data: SecureCrypto.text("archive", user: user, id: archive.id, key: archive.publicKey), identity: identity)
    }

    static func open(_ message: SecureV2Message, purpose: String, local: SecureLocalKeys,
                     archive: SecureArchiveKeys) throws -> Data {
        guard message.userId == local.userId, message.archiveId == archive.archive.id,
              let identity = local.identityPublicKey else { throw SecureFailure.invalid }
        try verify(archive.archive, user: local.userId, identity: identity)
        try SecureCrypto.verify(message.sourceCertificate,
            data: SecureCrypto.text("source", user: local.userId, id: message.sourceId, key: message.sourcePublicKey), identity: identity)
        let key = try P256.KeyAgreement.PrivateKey(rawRepresentation: archive.privateKey)
        guard key.publicKey.x963Representation.base64EncodedString() == archive.archive.publicKey else { throw SecureFailure.invalid }
        var recipient = try HPKE.Recipient(privateKey: key, ciphersuite: SecureCrypto.suite,
            info: Data("pushnow-v2".utf8), encapsulatedKey: SecureCrypto.decode(message.enc),
            authenticatedBy: P256.KeyAgreement.PublicKey(x963Representation: SecureCrypto.decode(message.sourcePublicKey)))
        return try recipient.open(SecureCrypto.decode(message.ciphertext), authenticating:
            aad([2, purpose, message.userId, message.sourceId, message.messageId, message.archiveId]))
    }

    static func sealGrant<T: Encodable>(_ value: T, publicKey: String, info: String, aad: Data) throws -> SecureApproval {
        var sender = try HPKE.Sender(recipientKey: P256.KeyAgreement.PublicKey(x963Representation: SecureCrypto.decode(publicKey)),
            ciphersuite: SecureCrypto.suite, info: Data(info.utf8))
        let ciphertext = try sender.seal(JSONEncoder.api.encode(value), authenticating: aad)
        return SecureApproval(enc: sender.encapsulatedKey.base64EncodedString(), ciphertext: ciphertext.base64EncodedString())
    }

    static func openGrant<T: Decodable>(_ grant: SecureApproval, privateKey: Data, info: String, aad: Data) throws -> T {
        var recipient = try HPKE.Recipient(privateKey: P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey),
            ciphersuite: SecureCrypto.suite, info: Data(info.utf8), encapsulatedKey: SecureCrypto.decode(grant.enc))
        return try JSONDecoder.api.decode(T.self, from: recipient.open(SecureCrypto.decode(grant.ciphertext), authenticating: aad))
    }

    static func attachment(_ encrypted: Data, descriptor: SecureAttachment, user: String, source: String) throws -> Data {
        guard descriptor.size >= 0, descriptor.size <= 20 * 1024 * 1024,
              encrypted.count == descriptor.size + 16 else { throw SecureFailure.invalid }
        let key = try SecureCrypto.decode(descriptor.key)
        let nonce = try SecureCrypto.decode(descriptor.nonce)
        guard key.count == 32, nonce.count == 12 else { throw SecureFailure.invalid }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: encrypted.dropLast(16), tag: encrypted.suffix(16))
        let clear = try AES.GCM.open(box, using: SymmetricKey(data: key),
            authenticating: aad([2, "attachment", user, source, descriptor.id]))
        let digest = SHA256.hash(data: clear).map { String(format: "%02x", $0) }.joined()
        guard clear.count == descriptor.size, digest == descriptor.sha256 else { throw SecureFailure.invalid }
        return clear
    }
}
