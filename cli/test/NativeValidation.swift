import CryptoKit
import Foundation

enum AppLocalization {
    static var bundle: Bundle { .main }
    static var locale: Locale { Locale(identifier: "en") }
}

struct ValidationInput: Decodable {
    let messages: [SecureMessage]
    let keys: [SecureLocalKeys]
    let devices: [SecureDevice]
    let expected: SecurePlaintext
}

@main
struct NativeValidation {
    static func rejects(_ action: () throws -> Void) {
        do { try action(); fatalError("Expected verification rejection") } catch { }
    }

    static func main() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let input = try decoder.decode(ValidationInput.self, from: FileHandle.standardInput.readDataToEndOfFile())
        for index in input.messages.indices {
            let clear = try SecureCrypto.decrypt(input.messages[index], keys: input.keys[index])
            precondition(clear.title == input.expected.title && clear.body == input.expected.body)
        }
        let original = input.messages[0]
        rejects { _ = try SecureCrypto.decrypt(original, keys: input.keys[1]) }
        var changed = original
        changed.sourceId = UUID().uuidString
        rejects { _ = try SecureCrypto.decrypt(changed, keys: input.keys[0]) }
        changed = original
        changed.ciphertext = Data(repeating: 0, count: 40).base64EncodedString()
        rejects { _ = try SecureCrypto.decrypt(changed, keys: input.keys[0]) }
        changed = original
        changed.expiresAt = "2000-01-01T00:00:00.000Z"
        rejects { _ = try SecureCrypto.decrypt(changed, keys: input.keys[0]) }
        let root = input.keys[0].identityPrivateKey!
        let approval = try SecureCrypto.approval(for: input.devices[1], identityPrivateKey: root)
        var pending = input.keys[1]
        pending.identityPrivateKey = nil
        pending.identityPublicKey = nil
        let accepted = try SecureCrypto.accept(approval, device: input.devices[1], keys: pending,
            identity: input.keys[0].identityPublicKey!)
        precondition(accepted.identityPrivateKey == root)
        rejects {
            _ = try SecureCrypto.accept(approval, device: input.devices[1], keys: pending,
                identity: P256.Signing.PrivateKey().publicKey.x963Representation.base64EncodedString())
        }
        rejects {
            _ = try SecureCrypto.accept(approval, device: input.devices[0], keys: input.keys[0],
                identity: input.keys[0].identityPublicKey!)
        }
        print("PASS: production SecureCrypto two-device Auth HPKE, wrong device/source/ciphertext/expiry rejection, approval identity transfer and substitution rejection")
    }
}
