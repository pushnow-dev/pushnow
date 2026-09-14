import Foundation
import UserNotifications

@MainActor
enum SecureV2Inbox {
    static func messages(api: APIClient, auth: AuthService) async throws -> [(SecureV2Message, SecureV2Content)] {
        let epoch = auth.generation
        let service = auth.secureDevices(api: api)
        if !service.trusted { try await service.enroll() }
        guard let local = service.keys, service.trusted else { throw SecureFailure.pending }
        let archive: SecureArchiveKeys
        do {
            archive = try await SecureArchiveService.ensure(service: service)
            service.historyAccessPending = false
        } catch SecureFailure.pending {
            service.historyAccessPending = true
            throw SecureFailure.pending
        }
        var result: [(SecureV2Message, SecureV2Content)] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            let suffix = cursor.map { "&cursor=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" } ?? ""
            let page: SecureV2Page = try await api.getJSON("/v2/messages?limit=50\(suffix)", accessToken: await auth.requireAccessToken())
            try check(auth, local: local, epoch: epoch)
            for message in page.messages where seen.insert(message.messageId).inserted {
                let clear = try SecureV2Crypto.open(message, purpose: "message", local: local, archive: archive)
                result.append((message, try JSONDecoder.api.decode(SecureV2Content.self, from: clear)))
            }
            await purge(page.deletedIds, user: local.userId)
            guard page.nextCursor != cursor || page.nextCursor == nil else { throw SecureFailure.invalid }
            cursor = page.nextCursor
        } while cursor != nil
        try await syncDeletions(api: api, auth: auth, local: local, epoch: epoch)
        try check(auth, local: local, epoch: epoch)
        return try result.filter { try SecureKeyStore().read("deleted:\(local.userId):\($0.0.messageId)") == nil }
    }

    static func message(id: String, api: APIClient, auth: AuthService) async throws -> (SecureV2Message, SecureV2Content) {
        let epoch = auth.generation
        let user = auth.session?.userID
        do { return try await remoteMessage(id: id, api: api, auth: auth) }
        catch {
            guard auth.generation == epoch, auth.session?.userID == user else { throw SecureFailure.invalid }
            if let status = error as? APIStatusError, let user {
                if [404, 410].contains(status.statusCode) { await purge([id], user: user) }
                if [401, 403].contains(status.statusCode) { EncryptedNotificationCache.shared.removeAccount(user: user) }
            }
            if NotificationHistoryCache.isOffline(error), let cached = NotificationHistoryCache.message(id: id, auth: auth) {
                return (cached.message, cached.content)
            }
            throw error
        }
    }

    private static func remoteMessage(id: String, api: APIClient, auth: AuthService) async throws -> (SecureV2Message, SecureV2Content) {
        let epoch = auth.generation
        let service = auth.secureDevices(api: api)
        if !service.trusted { try await service.enroll() }
        guard let local = service.keys else { throw SecureFailure.pending }
        let archive = try await SecureArchiveService.ensure(service: service)
        let response: MessageResponse = try await api.getJSONWithStatus("/v2/messages/\(id)", accessToken: await auth.requireAccessToken())
        try check(auth, local: local, epoch: epoch)
        let clear = try SecureV2Crypto.open(response.message, purpose: "message", local: local, archive: archive)
        let content = try JSONDecoder.api.decode(SecureV2Content.self, from: clear)
        NotificationHistoryCache.saveMessage(response.message, content: content, local: local)
        return (response.message, content)
    }

    static func item(_ message: SecureV2Message, content: SecureV2Content) -> InboxItem {
        InboxItem(id: "v2:\(message.messageId)", source: message.sourceName ?? AppLocalization.text("Encrypted source", language: AppLocalization.language),
            category: AppLocalization.text("Encrypted", language: AppLocalization.language), title: content.title,
            summary: content.body, time: message.createdAt?.jzRelativeLabel ?? "", icon: "lock.shield", unread: message.readAt == nil,
            priority: .normal, reminderBadge: nil, requiresAck: false, pushEnabled: true,
            secureIcon: content.attachments.first(where: { $0.id == content.iconId }).map { SecureIconContext(message: message, attachment: $0) },
            receivedAt: message.createdAt, sourceKind: message.sourceKind, sourceType: message.sourceType)
    }

    static func delete(id: String, api: APIClient, auth: AuthService) async throws {
        guard let user = auth.session?.userID else { throw SecureFailure.invalid }
        try await api.deleteNoResponse("/v2/messages/\(id)", accessToken: await auth.requireAccessToken())
        await purge([id], user: user)
    }

    static func purge(_ ids: [String], user: String) async {
        guard !ids.isEmpty else { return }
        let deleted = Set(ids)
        if let local = try? SecureKeyStore().load(user: user) {
            NotificationHistoryCache.remove(ids: ids, user: user, device: local.deviceId)
        }
        for id in ids {
            try? SecureKeyStore().write(Data([1]), account: "deleted:\(user):\(id)")
            SecureAttachmentService.removeFiles(user: user, message: id)
            NotificationCenter.default.post(name: SecureHistoryEvent.name,
                object: SecureHistoryEvent(user: user, id: id, deleted: true))
        }
        let center = UNUserNotificationCenter.current()
        let notifications = await center.deliveredNotifications()
        let matches = notifications.filter {
            guard let payload = $0.request.content.userInfo["secure_v2"] as? [String: Any],
                  payload["user_id"] as? String == user, let id = payload["message_id"] as? String else { return false }
            return deleted.contains(id)
        }.map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: matches)
    }

    private static func syncDeletions(api: APIClient, auth: AuthService, local: SecureLocalKeys, epoch: UUID) async throws {
        var cursor: String?
        repeat {
            let suffix = cursor.map { "?cursor=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" } ?? ""
            let page: SecureDeletionPage = try await api.getJSON("/v2/deletions\(suffix)", accessToken: await auth.requireAccessToken())
            try check(auth, local: local, epoch: epoch)
            await purge(page.deletedIds, user: local.userId)
            guard page.nextCursor != cursor || page.nextCursor == nil else { throw SecureFailure.invalid }
            cursor = page.nextCursor
        } while cursor != nil
    }

    static func check(_ auth: AuthService, local: SecureLocalKeys, epoch: UUID) throws {
        guard auth.generation == epoch, auth.session?.userID == local.userId,
              try SecureKeyStore().active()?.deviceId == local.deviceId else { throw SecureFailure.invalid }
    }
}
private struct MessageResponse: Decodable { var message: SecureV2Message }
