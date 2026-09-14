import Foundation

enum SecureAttachmentService {
    static func removeAccountFiles(user: String) {
        guard UUID(uuidString: user) != nil else { return }
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory
            .appending(path: ServerEnvironment.current.key("pushnow-attachments")).appending(path: user))
    }
    static func directory(user: String, message: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: ServerEnvironment.current.key("pushnow-attachments"))
            .appending(path: user).appending(path: message)
    }

    static func removeFiles(user: String, message: String) {
        try? FileManager.default.removeItem(at: directory(user: user, message: message))
    }

    @MainActor
    static func retrieve(_ descriptor: SecureAttachment, message: SecureV2Message,
                         api: APIClient, auth: AuthService) async throws -> URL {
        let epoch = auth.generation
        guard let local = try SecureKeyStore().active(), local.userId == message.userId else { throw SecureFailure.invalid }
        guard UUID(uuidString: descriptor.id) != nil, UUID(uuidString: message.messageId) != nil,
              UUID(uuidString: message.userId) != nil else { throw SecureFailure.invalid }
        guard try SecureKeyStore().read("deleted:\(message.userId):\(message.messageId)") == nil else { throw SecureFailure.invalid }
        let cache = EncryptedNotificationCache.shared
        let cacheName = "attachment:\(message.messageId):\(descriptor.id)"
        var encrypted = try? cache.read(user: local.userId, device: local.deviceId, name: cacheName)
        var clear = encrypted.flatMap { try? SecureV2Crypto.attachment($0, descriptor: descriptor, user: message.userId, source: message.sourceId) }
        if clear == nil {
            cache.remove(user: local.userId, device: local.deviceId, name: cacheName)
            var request = URLRequest(url: api.baseURL.appending(path: "v2/attachments/\(descriptor.id)"))
            request.setValue("Bearer \(try await auth.requireAccessToken())", forHTTPHeaderField: "Authorization")
            let (data, response) = try await api.session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url == request.url else { throw SecureFailure.invalid }
            encrypted = data
            clear = try SecureV2Crypto.attachment(data, descriptor: descriptor, user: message.userId, source: message.sourceId)
        }
        try SecureV2Inbox.check(auth, local: local, epoch: epoch)
        guard try SecureKeyStore().read("deleted:\(message.userId):\(message.messageId)") == nil else { throw SecureFailure.invalid }
        guard let clear, let encrypted else { throw SecureFailure.invalid }
        NotificationHistoryCache.saveAttachment(encrypted, id: descriptor.id, message: message.messageId, local: local)
        let directory = directory(user: message.userId, message: message.messageId)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        let fileName = URL(fileURLWithPath: descriptor.name).lastPathComponent
        guard !fileName.isEmpty, fileName != ".", fileName != ".." else { throw SecureFailure.invalid }
        let file = directory.appending(path: "\(descriptor.id)-\(fileName)")
        try clear.write(to: file, options: [.atomic, .completeFileProtection])
        return file
    }
}
