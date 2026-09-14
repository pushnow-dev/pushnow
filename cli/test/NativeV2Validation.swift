import CryptoKit
import Foundation

enum AppLocalization {
    static var bundle: Bundle { .main }
    static var locale: Locale { Locale(identifier: "en") }
}
struct NativeV2Input: Decodable {
    var message: SecureV2Message
    var local: SecureLocalKeys
    var archive: SecureArchiveKeys
    var attachment: SecureAttachment
    var ciphertext: Data
    var expectedAttachment: Data
}
@main struct NativeV2Validation {
    static func rejects(_ action: () throws -> Void) {
        do { try action(); fatalError("Expected rejection") } catch { }
    }
    static func main() throws {
        let input = try JSONDecoder.api.decode(NativeV2Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
        let clear = try SecureV2Crypto.open(input.message, purpose: "message", local: input.local, archive: input.archive)
        let content = try JSONDecoder.api.decode(SecureV2Content.self, from: clear)
        precondition(content.title == "Encrypted archive")
        var preview = input.message
        preview.enc = input.message.preview!.enc
        preview.ciphertext = input.message.preview!.ciphertext
        let brief = try JSONDecoder.api.decode(SecureV2Preview.self,
            from: SecureV2Crypto.open(preview, purpose: "preview", local: input.local, archive: input.archive))
        precondition(brief.title == content.title)
        rejects { _ = try SecureV2Crypto.open(preview, purpose: "message", local: input.local, archive: input.archive) }
        var foreign = input.local
        foreign.userId = UUID().uuidString
        rejects { _ = try SecureV2Crypto.open(input.message, purpose: "message", local: foreign, archive: input.archive) }
        var wrong = input.archive
        wrong.privateKey = P256.KeyAgreement.PrivateKey().rawRepresentation
        rejects { _ = try SecureV2Crypto.open(input.message, purpose: "message", local: input.local, archive: wrong) }
        let attachment = try SecureV2Crypto.attachment(input.ciphertext, descriptor: input.attachment,
            user: input.message.userId, source: input.message.sourceId)
        precondition(attachment == input.expectedAttachment)
        rejects { _ = try SecureV2Crypto.attachment(input.ciphertext, descriptor: input.attachment,
            user: "foreign", source: input.message.sourceId) }
        print("PASS production SecureV2Crypto full/preview/archive/account validation and attachment decrypt/tamper")
    }
}
