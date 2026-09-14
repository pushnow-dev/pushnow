import Foundation
import UserNotifications

final class SecurePreviewLoader: NSObject, URLSessionTaskDelegate {
    func load(envelope: [String: Any], content: UNMutableNotificationContent) async throws {
        let store = SecureKeyStore()
        guard let local = try store.active(),
              let data = try store.read("archive:\(local.userId)") else { throw SecureFailure.invalid }
        let archive = try JSONDecoder.api.decode(SecureArchiveKeys.self, from: data)
        let message = try JSONDecoder.api.decode(SecureV2Message.self, from: JSONSerialization.data(withJSONObject: envelope))
        guard message.deviceId == local.deviceId,
              try store.read("deleted:\(local.userId):\(message.messageId)") == nil else { throw SecureFailure.invalid }
        let clear = try SecureV2Crypto.open(message, purpose: "preview", local: local, archive: archive)
        let preview = try JSONDecoder.api.decode(SecureV2Preview.self, from: clear)
        guard try store.claimNotification("v2:\(message.messageId)", keys: local),
              try store.active()?.deviceId == local.deviceId else { throw SecureFailure.invalid }
        content.title = preview.title
        content.body = preview.body
        if let image = preview.image, image.mime.hasPrefix("image/"), image.size <= 10 * 1024 * 1024 {
            do {
                let attachment = try await loadImage(image, message: message, environment: store.environment)
                guard try store.active()?.deviceId == local.deviceId,
                      try store.read("deleted:\(local.userId):\(message.messageId)") == nil else { throw SecureFailure.invalid }
                content.attachments = [attachment]
            } catch { /* A failed image download does not expose unverified bytes. */ }
        }
        guard try store.active()?.deviceId == local.deviceId,
              try store.read("deleted:\(local.userId):\(message.messageId)") == nil else { throw SecureFailure.invalid }
    }

    private func loadImage(_ image: SecureAttachment, message: SecureV2Message, environment: ServerEnvironment) async throws -> UNNotificationAttachment {
        guard UUID(uuidString: image.id) != nil else { throw SecureFailure.invalid }
        let baseURL = environment.apiURL
        var request = URLRequest(url: baseURL.appending(path: "v2/attachments/\(image.id)"))
        request.setValue("Attachment \(image.readToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 12
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (url, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: url) }
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url == request.url else { throw SecureFailure.invalid }
        let encrypted = try Data(contentsOf: url, options: .mappedIfSafe)
        let clear = try SecureV2Crypto.attachment(encrypted, descriptor: image, user: message.userId, source: message.sourceId)
        let suffix: String
        switch image.mime {
        case "image/jpeg": suffix = "jpg"
        case "image/png": suffix = "png"
        case "image/gif": suffix = "gif"
        default: throw SecureFailure.invalid
        }
        let target = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(suffix)")
        try clear.write(to: target, options: [.atomic, .completeFileProtectionUnlessOpen])
        return try UNNotificationAttachment(identifier: image.id, url: target)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
