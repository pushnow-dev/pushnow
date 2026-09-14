import Foundation

struct CachedSecureMessage: Codable {
    var message: SecureV2Message
    var content: SecureV2Content
}

struct CachedInboxSnapshot: Codable {
    var items: [InboxItem]
    var timestamps: [String: String]
    var savedAt: String
}

@MainActor
enum NotificationHistoryCache {
    static func context(auth: AuthService) -> SecureLocalKeys? {
        guard auth.isVerified, let local = try? SecureKeyStore().active(),
              local.userId == auth.session?.userID, local.identityPrivateKey != nil else { return nil }
        return local
    }

    static func inbox(auth: AuthService) -> [InboxItem]? {
        guard let local = context(auth: auth),
              let snapshot = try? EncryptedNotificationCache.shared.load(CachedInboxSnapshot.self,
                user: local.userId, device: local.deviceId, name: "inbox") else { return nil }
        guard let deleted = try? SecureKeyStore().deletedMessageIDs(user: local.userId) else { return nil }
        let readIDs = readItems(user: local.userId, device: local.deviceId, cache: .shared)
        return snapshot.items.filter { !$0.id.hasPrefix("v2:") || !deleted.contains(String($0.id.dropFirst(3))) }.map { item in
            var item = item
            if readIDs.contains(item.id) { item.unread = false }
            if let timestamp = item.receivedAt ?? snapshot.timestamps[item.id] { item.time = timestamp.jzRelativeLabel }
            return item
        }
    }

    static func saveInbox(_ items: [InboxItem], timestamps: [String: String], local: SecureLocalKeys) {
        let snapshot = CachedInboxSnapshot(items: items, timestamps: timestamps, savedAt: ISO8601DateFormatter().string(from: Date()))
        try? EncryptedNotificationCache.shared.save(snapshot, user: local.userId, device: local.deviceId, name: "inbox")
    }

    static func reconcile(_ items: [InboxItem], local: SecureLocalKeys, cache: EncryptedNotificationCache = .shared) throws -> [InboxItem] {
        let previous = try? cache.load(CachedInboxSnapshot.self,
            user: local.userId, device: local.deviceId, name: "inbox")
        let readIDs = Set(previous?.items.filter { !$0.unread }.map(\.id) ?? [])
            .union(readItems(user: local.userId, device: local.deviceId, cache: cache))
        let deleted = try SecureKeyStore().deletedMessageIDs(user: local.userId)
        return items.filter { !$0.id.hasPrefix("v2:") || !deleted.contains(String($0.id.dropFirst(3))) }.map { item in
            var item = item
            if readIDs.contains(item.id) { item.unread = false }
            return item
        }
    }

    static func saveMessage(_ message: SecureV2Message, content: SecureV2Content, local: SecureLocalKeys) {
        guard message.userId == local.userId else { return }
        do {
            guard try SecureKeyStore().read("deleted:\(local.userId):\(message.messageId)") == nil else { return }
            let cache = EncryptedNotificationCache.shared
            var message = message
            if let previous = try? cache.load(CachedSecureMessage.self, user: local.userId, device: local.deviceId, name: "message:\(message.messageId)") {
                if let readAt = previous.message.readAt { message.readAt = readAt }
                if previous.message == message, previous.content == content { return }
            }
            try cache.save(CachedSecureMessage(message: message, content: content),
                user: local.userId, device: local.deviceId, name: "message:\(message.messageId)")
        } catch { /* Keep cache errors separate from verified network content. */ }
    }

    static func message(id: String, auth: AuthService) -> CachedSecureMessage? {
        guard let local = context(auth: auth) else { return nil }
        do {
            guard try SecureKeyStore().read("deleted:\(local.userId):\(id)") == nil else { return nil }
            return try EncryptedNotificationCache.shared.load(CachedSecureMessage.self,
                user: local.userId, device: local.deviceId, name: "message:\(id)")
        } catch { return nil }
    }

    static func isOffline(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [.notConnectedToInternet, .timedOut, .cannotConnectToHost, .cannotFindHost,
                .networkConnectionLost, .dnsLookupFailed].contains(error.code)
    }

    static func saveAttachment(_ data: Data, id: String, message: String, local: SecureLocalKeys) {
        let cache = EncryptedNotificationCache.shared
        do {
            var ids = (try? cache.load([String].self, user: local.userId, device: local.deviceId,
                name: "attachments:\(message)")) ?? []
            if !ids.contains(id) { ids.append(id) }
            try cache.save(ids, user: local.userId, device: local.deviceId, name: "attachments:\(message)")
            try cache.write(data, user: local.userId, device: local.deviceId, name: "attachment:\(message):\(id)")
        } catch { /* A failed optional cache write does not discard a verified download. */ }
    }

    static func apply(_ event: SecureHistoryEvent, device: String, cache: EncryptedNotificationCache = .shared) {
        if !event.deleted {
            var readIDs = readItems(user: event.user, device: device, cache: cache)
            readIDs.insert(event.inboxItemID)
            try? cache.save(readIDs.sorted(), user: event.user, device: device, name: "read-items")
        }
        let v2ID = event.inboxItemID.hasPrefix("v2:") ? String(event.inboxItemID.dropFirst(3)) : nil
        if event.deleted, let v2ID {
            remove(ids: [v2ID], user: event.user, device: device, cache: cache)
            return
        }
        if var snapshot = try? cache.load(CachedInboxSnapshot.self, user: event.user, device: device, name: "inbox") {
            if event.deleted {
                snapshot.items.removeAll { $0.id == event.inboxItemID }
                snapshot.timestamps.removeValue(forKey: event.inboxItemID)
            } else if let index = snapshot.items.firstIndex(where: { $0.id == event.inboxItemID }) {
                snapshot.items[index].unread = false
            }
            try? cache.save(snapshot, user: event.user, device: device, name: "inbox")
        }
        // Legacy and v1 IDs may share a raw ID with v2, but never its encrypted detail record.
        guard !event.deleted, let v2ID else { return }
        if var message = try? cache.load(CachedSecureMessage.self, user: event.user, device: device, name: "message:\(v2ID)") {
            message.message.readAt = message.message.readAt ?? ISO8601DateFormatter().string(from: Date())
            try? cache.save(message, user: event.user, device: device, name: "message:\(v2ID)")
        }
    }

    private static func readItems(user: String, device: String, cache: EncryptedNotificationCache) -> Set<String> {
        Set((try? cache.load([String].self, user: user, device: device, name: "read-items")) ?? [])
    }

    static func remove(ids: [String], user: String, device: String, cache: EncryptedNotificationCache = .shared) {
        let deleted = Set(ids.map { "v2:\($0)" })
        if var snapshot = try? cache.load(CachedInboxSnapshot.self, user: user, device: device, name: "inbox") {
            let originalCount = snapshot.items.count
            snapshot.items.removeAll { deleted.contains($0.id) }
            if originalCount != snapshot.items.count {
                snapshot.timestamps = snapshot.timestamps.filter { !deleted.contains($0.key) }
                try? cache.save(snapshot, user: user, device: device, name: "inbox")
            }
        }
        for message in ids {
            if let attachments = try? cache.load([String].self, user: user, device: device, name: "attachments:\(message)") {
                for id in attachments { cache.remove(user: user, device: device, name: "attachment:\(message):\(id)") }
            }
            cache.remove(user: user, device: device, name: "attachments:\(message)")
            cache.remove(user: user, device: device, name: "message:\(message)")
        }
    }
}
