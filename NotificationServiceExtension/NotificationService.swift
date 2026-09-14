import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private var handler: ((UNNotificationContent) -> Void)?
    private var fallback: UNMutableNotificationContent?
    private var task: Task<Void, Never>?
    private let completionLock = NSLock()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content); return
        }
        content.title = "Pushnow"
        content.body = String(localized: "You have a new encrypted reminder", bundle: AppLocalization.notificationBundle, locale: AppLocalization.notificationLocale)
        content.subtitle = ""
        content.attachments = []
        completionLock.lock()
        handler = contentHandler
        fallback = content
        completionLock.unlock()
        if let envelope = request.content.userInfo["secure_v2"] as? [String: Any] {
            let decrypted = content.mutableCopy() as! UNMutableNotificationContent
            let payload = SecurePreviewPayload(envelope: envelope, decrypted: decrypted, fallback: content)
            let work = Task {
                do {
                    try await SecurePreviewLoader().load(envelope: payload.envelope, content: payload.decrypted)
                    if !Task.isCancelled { finish(payload.decrypted) }
                } catch { finish(payload.fallback) }
            }
            completionLock.lock()
            task = work
            completionLock.unlock()
            return
        }
        do {
            let store = SecureKeyStore()
            guard let keys = try store.active(),
                  let envelope = request.content.userInfo["secure"] as? [String: Any] else { throw SecureFailure.invalid }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let message = try decoder.decode(SecureMessage.self, from: JSONSerialization.data(withJSONObject: envelope))
            let clear = try SecureCrypto.decrypt(message, keys: keys)
            // SecItemAdd is atomic across extension processes: only one delivery claims the ID.
            guard try store.claimNotification(message.messageId, keys: keys) else { throw SecureFailure.invalid }
            guard try store.active()?.deviceId == keys.deviceId else { throw SecureFailure.invalid }
            content.title = clear.title
            content.body = clear.body
        } catch { /* Keep the generic, non-sensitive notification on any validation failure. */ }
        finish(content)
    }

    override func serviceExtensionTimeWillExpire() {
        completionLock.lock()
        let work = task
        let fallback = fallback
        completionLock.unlock()
        work?.cancel()
        if let fallback { finish(fallback) }
    }

    private func finish(_ content: UNNotificationContent) {
        completionLock.lock()
        let callback = handler
        handler = nil
        completionLock.unlock()
        callback?(content)
    }
}

private final class SecurePreviewPayload: @unchecked Sendable {
    let envelope: [String: Any]
    let decrypted: UNMutableNotificationContent
    let fallback: UNNotificationContent

    init(envelope: [String: Any], decrypted: UNMutableNotificationContent, fallback: UNNotificationContent) {
        self.envelope = envelope
        self.decrypted = decrypted
        self.fallback = fallback
    }
}
