import Foundation

@MainActor
struct RemoteJiZhiRepository: JiZhiRepository {
    private let apiClient: APIClient
    private let authService: AuthService
    private let fallback: PreviewJiZhiRepository

    init(apiClient: APIClient, authService: AuthService, fallback: PreviewJiZhiRepository = PreviewJiZhiRepository()) {
        self.apiClient = apiClient
        self.authService = authService
        self.fallback = fallback
    }

    func loadInbox() async throws -> [InboxItem] {
        let epoch = authService.generation
        try await authService.secureDevices(api: apiClient).enroll()
        let token = try await authService.requireAccessToken()
        async let sourceRequest = sourceMap(accessToken: token)
        async let itemRequest: ItemsResponse = apiClient.getJSON("/v1/items?limit=100", accessToken: token)
        let (sources, response) = try await (sourceRequest, itemRequest)
        let encrypted = try await SecureInbox.messages(api: apiClient, auth: authService)
        let shared: [(SecureV2Message, SecureV2Content)]
        do { shared = try await SecureV2Inbox.messages(api: apiClient, auth: authService) }
        catch SecureFailure.pending { shared = [] }
        var items = shared.map { SecureV2Inbox.item($0.0, content: $0.1) } + encrypted.map { SecureInbox.item($0.0, content: $0.1) } + response.items.map { item in
            item.inboxItem(sourceName: sources[item.sourceId]?.name ?? "Agent", sourceType: sources[item.sourceId]?.sourceType ?? "agent")
        }
        guard epoch == authService.generation else { throw SecureFailure.invalid }
        if let local = NotificationHistoryCache.context(auth: authService) {
            items = InboxOrder.newestFirst(try NotificationHistoryCache.reconcile(items, local: local), receivedAt: \.receivedAt)
            var timestamps = Dictionary(uniqueKeysWithValues: encrypted.map { ("secure:\($0.0.messageId)", $0.0.createdAt) })
            for (message, content) in shared {
                timestamps["v2:\(message.messageId)"] = message.createdAt
                NotificationHistoryCache.saveMessage(message, content: content, local: local)
            }
            NotificationHistoryCache.saveInbox(items, timestamps: timestamps, local: local)
        }
        return InboxOrder.newestFirst(items, receivedAt: \.receivedAt)
    }

    func cachedInbox() -> [InboxItem]? {
        NotificationHistoryCache.inbox(auth: authService).map { InboxOrder.newestFirst($0, receivedAt: \.receivedAt) }
    }

    func updateCachedInbox(_ event: SecureHistoryEvent) {
        guard let local = NotificationHistoryCache.context(auth: authService), local.userId == event.user else { return }
        NotificationHistoryCache.apply(event, device: local.deviceId)
    }

    func recordItemRead(_ itemID: InboxItem.ID) {
        guard authService.isVerified, let user = authService.session?.userID else { return }
        let messageID = itemID.hasPrefix("v2:") ? String(itemID.dropFirst(3)) : itemID
        let event = SecureHistoryEvent(user: user, id: messageID, deleted: false, itemID: itemID)
        updateCachedInbox(event)
        NotificationCenter.default.post(name: SecureHistoryEvent.name, object: event)
    }

    private func recordItemDeleted(_ itemID: InboxItem.ID) {
        guard authService.isVerified, let user = authService.session?.userID else { return }
        let messageID: String
        if itemID.hasPrefix("v2:") {
            messageID = String(itemID.dropFirst(3))
        } else if itemID.hasPrefix("secure:") {
            messageID = String(itemID.dropFirst(7))
        } else {
            messageID = itemID
        }
        let event = SecureHistoryEvent(user: user, id: messageID, deleted: true, itemID: itemID)
        updateCachedInbox(event)
        NotificationCenter.default.post(name: SecureHistoryEvent.name, object: event)
    }

    func loadContentModules(for itemID: InboxItem.ID) async throws -> [ContentModule] {
        if itemID.hasPrefix("secure:") {
            let messages = try await SecureInbox.messages(api: apiClient, auth: authService)
            guard let content = messages.first(where: { "secure:\($0.0.messageId)" == itemID })?.1 else { throw SecureFailure.invalid }
            return [ContentModule(id: itemID, icon: "lock.shield", title: content.title, subtitle: content.body)]
        }
        let token = try await authService.requireAccessToken()
        let response: ItemResponse = try await apiClient.getJSON("/v1/items/\(itemID)", accessToken: token)
        return response.item.contentModules
    }

    func updateItemState(_ itemID: InboxItem.ID, status: ItemStatusUpdate?, acknowledged: Bool) async throws {
        let generation = authService.generation
        if itemID.hasPrefix("v2:") {
            try await apiClient.postJSONNoResponse("/v2/messages/\(itemID.dropFirst(3))/read", body: [String: String](),
                accessToken: await authService.requireAccessToken())
        } else if itemID.hasPrefix("secure:") {
            let action = acknowledged ? "ack" : "read"
            try await apiClient.postJSONNoResponse("/v1/secure/messages/\(itemID.dropFirst(7))/\(action)",
                body: [String: String](), accessToken: await authService.requireAccessToken())
        } else {
            let token = try await authService.requireAccessToken()
            let request = UpdateItemStateRequest(status: status?.rawValue, acknowledged: acknowledged)
            let _: ItemResponse = try await apiClient.patchJSON("/v1/items/\(itemID)/state", body: request, accessToken: token)
        }
        guard generation == authService.generation else { return }
        if status == .read || acknowledged { recordItemRead(itemID) }
    }

    func deleteItem(_ itemID: InboxItem.ID) async throws {
        let generation = authService.generation
        if itemID.hasPrefix("v2:") {
            try await SecureV2Inbox.delete(id: String(itemID.dropFirst(3)), api: apiClient, auth: authService)
        } else if itemID.hasPrefix("secure:") {
            try await apiClient.postJSONNoResponse("/v1/secure/messages/\(itemID.dropFirst(7))/read",
                body: [String: String](), accessToken: await authService.requireAccessToken())
        } else {
            let token = try await authService.requireAccessToken()
            let request = UpdateItemStateRequest(status: ItemStatusUpdate.archived.rawValue, acknowledged: false)
            let _: ItemResponse = try await apiClient.patchJSON("/v1/items/\(itemID)/state", body: request, accessToken: token)
        }
        guard generation == authService.generation else { return }
        recordItemDeleted(itemID)
    }

    func createReminder(for itemID: InboxItem.ID, input: ReminderCreationInput) async throws {
        guard !itemID.hasPrefix("secure:"), !itemID.hasPrefix("v2:") else { throw AppError.underlying(String(localized: "Schedule encrypted reminders from your sender", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) }
        let token = try await authService.requireAccessToken()
        let request = CreateReminderRequest(
            mode: input.mode,
            scheduledAt: input.scheduledAt,
            timezone: input.timezone,
            repeatRule: input.repeatRule,
            priority: input.priority,
            pushEnabled: input.pushEnabled,
            requiresAck: input.requiresAck
        )
        let _: ReminderResponse = try await apiClient.postJSON("/v1/items/\(itemID)/reminders", body: request, accessToken: token)
    }

    func loadPersonalSources() async throws -> [SourceChannel] {
        let token = try await authService.requireAccessToken()
        let response: SourcesResponse = try await apiClient.getJSON("/v1/sources", accessToken: token)
        return response.sources.map(\.sourceChannel)
    }

    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential {
        let token = try await authService.requireAccessToken()
        let request = CreateSourceRequest(
            name: input.name,
            sourceType: input.sourceType.rawValue,
            defaultPriority: input.defaultPriority,
            defaultPushEnabled: input.defaultPushEnabled
        )
        let sourceResponse: SourceResponse = try await apiClient.postJSON("/v1/sources", body: request, accessToken: token)
        let keyResponse: SourceKeyResponse = try await apiClient.postJSON(
            "/v1/sources/\(sourceResponse.source.id)/keys",
            body: CreateSourceKeyRequest(scopes: ["items:write"]),
            accessToken: token
        )
        return CreatedSourceCredential(source: sourceResponse.source.sourceChannel, sourceKey: keyResponse.sourceKey)
    }

    func loadSubscribedChannels() async throws -> [SourceChannel] {
        try await fallback.loadSubscribedChannels()
    }

    func loadDiscoverChannels() async throws -> [DiscoverChannel] {
        try await fallback.loadDiscoverChannels()
    }

    func loadReminders() async throws -> [ReminderEntry] {
        let token = try await authService.requireAccessToken()
        let itemResponse: ItemsResponse = try await apiClient.getJSON("/v1/items?limit=100", accessToken: token)
        let sources = try await sourceMap(accessToken: token)
        let items = Dictionary(uniqueKeysWithValues: itemResponse.items.map { ($0.id, $0) })
        let response: RemindersResponse = try await apiClient.getJSON("/v1/reminders?limit=100", accessToken: token)
        return response.reminders.map { reminder in
            reminder.entry(item: items[reminder.itemId], source: items[reminder.itemId].flatMap { sources[$0.sourceId] })
        }
    }

    private func sourceMap(accessToken: String) async throws -> [String: APISource] {
        let response: SourcesResponse = try await apiClient.getJSON("/v1/sources", accessToken: accessToken)
        return Dictionary(uniqueKeysWithValues: response.sources.map { ($0.id, $0) })
    }
}

/// Orders all message formats together. Equal or unknown dates retain input order.
enum InboxOrder {
    static func newestFirst<Item>(_ items: [Item], receivedAt: (Item) -> String?) -> [Item] {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        return items.enumerated().map { index, item in
            let date = receivedAt(item).flatMap { fractional.date(from: $0) ?? standard.date(from: $0) }
            return (index: index, item: item, date: date)
        }.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (left?, right?) where left != right: return left > right
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.index < rhs.index
            }
        }.map(\.item)
    }
}
