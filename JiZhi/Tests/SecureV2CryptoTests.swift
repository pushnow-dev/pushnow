import CryptoKit
import XCTest
@testable import JiZhi

final class SecureV2CryptoTests: XCTestCase {
    func testAuthenticatedMessageSeparatesPreviewAndAccount() throws {
        let identity = P256.Signing.PrivateKey()
        let recipient = P256.KeyAgreement.PrivateKey()
        let source = P256.KeyAgreement.PrivateKey()
        let user = UUID().uuidString.lowercased()
        let sourceID = UUID().uuidString.lowercased()
        let archiveID = UUID().uuidString.lowercased()
        let messageID = UUID().uuidString.lowercased()
        let publicKey = source.publicKey.x963Representation.base64EncodedString()
        let archivePublic = recipient.publicKey.x963Representation.base64EncodedString()
        let archive = SecureArchive(id: archiveID, publicKey: archivePublic,
            certificate: try SecureCrypto.sign(SecureCrypto.text("archive", user: user, id: archiveID, key: archivePublic), privateKey: identity.rawRepresentation))
        let local = SecureLocalKeys(userId: user, deviceId: UUID().uuidString, privateKey: P256.KeyAgreement.PrivateKey().rawRepresentation,
            identityPublicKey: identity.publicKey.x963Representation.base64EncodedString(), identityPrivateKey: identity.rawRepresentation)
        var sender = try HPKE.Sender(recipientKey: recipient.publicKey, ciphersuite: SecureCrypto.suite,
            info: Data("pushnow-v2".utf8), authenticatedBy: source)
        let clear = Data("private message".utf8)
        let ciphertext = try sender.seal(clear, authenticating: SecureV2Crypto.aad([2, "message", user, sourceID, messageID, archiveID]))
        var message = SecureV2Message(messageId: messageID, userId: user, sourceId: sourceID, archiveId: archiveID,
            enc: sender.encapsulatedKey.base64EncodedString(), ciphertext: ciphertext.base64EncodedString(),
            sourcePublicKey: publicKey, sourceCertificate: try SecureCrypto.sign(SecureCrypto.text("source", user: user, id: sourceID, key: publicKey), privateKey: identity.rawRepresentation))
        let keys = SecureArchiveKeys(archive: archive, privateKey: recipient.rawRepresentation)
        XCTAssertEqual(try SecureV2Crypto.open(message, purpose: "message", local: local, archive: keys), clear)
        XCTAssertThrowsError(try SecureV2Crypto.open(message, purpose: "preview", local: local, archive: keys))
        message.userId = UUID().uuidString
        XCTAssertThrowsError(try SecureV2Crypto.open(message, purpose: "message", local: local, archive: keys))
    }

    func testAttachmentRejectsHashAndAADTampering() throws {
        let key = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        let clear = Data("attachment contents".utf8)
        let id = UUID().uuidString.lowercased()
        let box = try AES.GCM.seal(clear, using: key, nonce: nonce,
            authenticating: SecureV2Crypto.aad([2, "attachment", "user", "source", id]))
        let encrypted = box.ciphertext + box.tag
        var descriptor = SecureAttachment(id: id, name: "note.txt", mime: "text/plain", size: clear.count,
            key: key.withUnsafeBytes { Data($0).base64EncodedString() }, nonce: nonce.withUnsafeBytes { Data($0).base64EncodedString() },
            sha256: SHA256.hash(data: clear).map { String(format: "%02x", $0) }.joined(), readToken: "capability")
        XCTAssertEqual(try SecureV2Crypto.attachment(encrypted, descriptor: descriptor, user: "user", source: "source"), clear)
        XCTAssertThrowsError(try SecureV2Crypto.attachment(encrypted, descriptor: descriptor, user: "other", source: "source"))
        descriptor.sha256 = String(repeating: "0", count: 64)
        XCTAssertThrowsError(try SecureV2Crypto.attachment(encrypted, descriptor: descriptor, user: "user", source: "source"))
    }

    func testArchiveGrantBindsTargetAndUsesSnakeCase() throws {
        let recipient = P256.KeyAgreement.PrivateKey()
        let value = SecureArchiveTransfer(archiveId: "archive", archivePrivateKey: "private")
        let aad = try SecureV2Crypto.aad([2, "archive-grant", "user", "device", "archive"])
        let grant = try SecureV2Crypto.sealGrant(value, publicKey: recipient.publicKey.x963Representation.base64EncodedString(),
            info: "pushnow-archive-grant-v2", aad: aad)
        let decoded: SecureArchiveTransfer = try SecureV2Crypto.openGrant(grant, privateKey: recipient.rawRepresentation,
            info: "pushnow-archive-grant-v2", aad: aad)
        XCTAssertEqual(decoded.archivePrivateKey, "private")
        XCTAssertThrowsError(try SecureV2Crypto.openGrant(grant, privateKey: recipient.rawRepresentation,
            info: "pushnow-archive-grant-v2", aad: Data("other".utf8)) as SecureArchiveTransfer)
        let json = String(decoding: try JSONEncoder.api.encode(value), as: UTF8.self)
        XCTAssertTrue(json.contains("archive_private_key"))
    }
}
