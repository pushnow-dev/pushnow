import Foundation

@MainActor
enum SecureInbox {
    static func messages(api: APIClient, auth: AuthService) async throws -> [(SecureMessage, SecurePlaintext)] {
        let store = SecureKeyStore()
        let generation = auth.generation
        guard let keys = try store.active(), keys.userId == auth.session?.userID else { return [] }
        let response: SecureMessagesResponse = try await api.getJSON("/v1/secure/messages", accessToken: await auth.requireAccessToken())
        guard auth.generation == generation, auth.session?.userID == keys.userId,
              try store.active()?.deviceId == keys.deviceId else { throw SecureFailure.invalid }
        return try response.messages.map { ($0, try SecureCrypto.decrypt($0, keys: keys)) }
    }

    static func item(_ message: SecureMessage, content: SecurePlaintext) -> InboxItem {
        InboxItem(id: "secure:\(message.messageId)", source: message.sourceName ?? String(localized: "Encrypted source", bundle: AppLocalization.bundle, locale: AppLocalization.locale), category: String(localized: "Encrypted", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
            title: content.title, summary: content.body, time: message.createdAt, icon: "lock.shield",
            unread: message.readAt == nil, priority: .normal, reminderBadge: nil, requiresAck: true, pushEnabled: true, receivedAt: message.createdAt, sourceKind: message.sourceKind, sourceType: message.sourceType)
    }
}
private struct SecureMessagesResponse: Decodable { var messages: [SecureMessage] }
