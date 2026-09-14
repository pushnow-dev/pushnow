import Foundation

struct SecureDevice: Codable, Identifiable, Sendable {
    var id: String
    var userId: String
    var name: String
    var platform: String
    var publicKey: String
    var certificate: String?
    var status: String
    var notificationsEnabled: Bool
    var lastSeenAt: String
    var createdAt: String
    var systemVersion: String? = nil
    var appVersion: String? = nil
    var model: String? = nil
}

struct SecureDirectory: Decodable {
    var identityPublicKey: String?
    var devices: [SecureDevice]
}

struct SecureMessage: Codable, Sendable {
    var messageId: String
    var userId: String
    var sourceId: String
    var deviceId: String
    var expiresAt: String
    var enc: String
    var ciphertext: String
    var sourcePublicKey: String
    var sourceCertificate: String
    var createdAt: String
    var readAt: String? = nil
    var sourceKind: String? = nil
    var sourceName: String? = nil
    var sourceType: String? = nil
}

struct SecurePlaintext: Codable, Sendable {
    var title: String
    var body: String
    var subtitle: String?
    var url: String?
}

struct SecureApproval: Codable, Sendable, Hashable {
    var enc: String
    var ciphertext: String
}

struct SecureLocalKeys: Codable {
    var userId: String
    var deviceId: String
    var privateKey: Data
    var identityPublicKey: String?
    var identityPrivateKey: Data?
    var identityEstablished: Bool?
    var archiveTransfer: SecureArchiveTransfer?
}

enum SecureFailure: LocalizedError {
    case invalid, pending, keychain(Int32)
    var errorDescription: String? {
        switch self {
        case .invalid: String(localized: "Encrypted message verification failed", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .pending: String(localized: "Approve this device from a trusted device", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .keychain: String(localized: "Secure storage is unavailable", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }
}
