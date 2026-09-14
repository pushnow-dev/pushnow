import CryptoKit
import Foundation

struct Input: Decodable {
    let key: Data
    let nonce: Data
    let ciphertext: Data
    let aad: String
    let sha256: String
}
do {
    let input = try JSONDecoder().decode(Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
    let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: input.nonce),
        ciphertext: input.ciphertext.dropLast(16), tag: input.ciphertext.suffix(16))
    let clear = try AES.GCM.open(box, using: SymmetricKey(data: input.key), authenticating: Data(input.aad.utf8))
    let digest = SHA256.hash(data: clear).map { String(format: "%02x", $0) }.joined()
    guard digest == input.sha256 else { exit(2) }
    FileHandle.standardOutput.write(clear)
} catch { exit(1) }
