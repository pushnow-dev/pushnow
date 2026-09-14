import Foundation

struct SecureHistoryEvent: Sendable {
    var user: String
    var id: String
    var deleted: Bool
    var itemID: String? = nil
    var inboxItemID: String { itemID ?? "v2:\(id)" }
    static let name = Notification.Name("PushnowSecureHistoryChanged")
}

struct SecureIconContext: Hashable, Sendable, Codable {
    var message: SecureV2Message
    var attachment: SecureAttachment
}

struct SecureArchive: Codable, Equatable, Sendable {
    var id: String
    var publicKey: String
    var certificate: String
}

struct SecureArchiveKeys: Codable, Sendable {
    var archive: SecureArchive
    var privateKey: Data
}

struct SecureV2Message: Codable, Identifiable, Sendable, Hashable {
    var messageId: String
    var userId: String
    var sourceId: String
    var archiveId: String
    var enc: String
    var ciphertext: String
    var preview: SecureApproval?
    var sourcePublicKey: String
    var sourceCertificate: String
    var createdAt: String?
    var readAt: String?
    var deviceId: String?
    var sourceKind: String? = nil
    var sourceName: String? = nil
    var sourceType: String? = nil
    var id: String { messageId }
}

struct SecureAttachment: Codable, Identifiable, Sendable, Hashable {
    var id: String
    var name: String
    var mime: String
    var size: Int
    var key: String
    var nonce: String
    var sha256: String
    var readToken: String
}

struct SecureV2Content: Codable, Sendable, Equatable {
    var title: String
    var body: String
    var links: [String]
    var attachments: [SecureAttachment]
    var iconId: String?
    var imageId: String?
}

struct SecureV2Preview: Codable {
    var title: String
    var body: String
    var image: SecureAttachment?
}

struct SecureArchiveTransfer: Codable {
    var archiveId: String
    var archivePrivateKey: String
}

struct SecureV2Page: Decodable {
    var messages: [SecureV2Message]
    var nextCursor: String?
    var deletedIds: [String]
}

struct SecureDeletionPage: Decodable {
    var deletedIds: [String]
    var nextCursor: String?
}
