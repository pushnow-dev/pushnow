import CryptoKit
import Foundation

// Standalone protocol interoperability harness, using throwaway keys only.
struct Input: Codable {
    let privateKey: String
    let senderPublicKey: String
    let envelope: Envelope
    let aad: String
    let identityPublicKey: String
    let certificate: String
    let certificateText: String
    let info: String?
}
struct Envelope: Codable {
    let enc: String
    let ciphertext: String
}
struct Output: Codable {
    let plaintext: String
    let enc: String
    let ciphertext: String
    let senderPublicKey: String
}
func data(_ value: String) throws -> Data {
    guard let bytes = Data(base64Encoded: value) else { throw NSError(domain: "base64", code: 1) }
    return bytes
}
do {
let inputData = FileHandle.standardInput.readDataToEndOfFile()
let input = try JSONDecoder().decode(Input.self, from: inputData)
let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: data(input.privateKey))
let sourceKey = try P256.KeyAgreement.PublicKey(x963Representation: data(input.senderPublicKey))
let identity = try P256.Signing.PublicKey(x963Representation: data(input.identityPublicKey))
let signature = try P256.Signing.ECDSASignature(rawRepresentation: data(input.certificate))
guard identity.isValidSignature(signature, for: Data(input.certificateText.utf8)) else {
    throw NSError(domain: "certificate", code: 1)
}
var recipient = try HPKE.Recipient(
    privateKey: privateKey, ciphersuite: .P256_SHA256_AES_GCM_256,
    info: Data((input.info ?? "pushnow-message-v1").utf8), encapsulatedKey: data(input.envelope.enc),
    authenticatedBy: sourceKey
)
let plaintext = try recipient.open(data(input.envelope.ciphertext), authenticating: Data(input.aad.utf8))
let swiftSenderKey = P256.KeyAgreement.PrivateKey()
var sender = try HPKE.Sender(
    recipientKey: privateKey.publicKey, ciphersuite: .P256_SHA256_AES_GCM_256,
    info: Data((input.info ?? "pushnow-message-v1").utf8), authenticatedBy: swiftSenderKey
)
let ciphertext = try sender.seal(plaintext, authenticating: Data(input.aad.utf8))
let output = Output(
    plaintext: String(decoding: plaintext, as: UTF8.self),
    enc: sender.encapsulatedKey.base64EncodedString(), ciphertext: ciphertext.base64EncodedString(),
    senderPublicKey: swiftSenderKey.publicKey.x963Representation.base64EncodedString()
)
FileHandle.standardOutput.write(try JSONEncoder().encode(output))
} catch {
    exit(1)
}
