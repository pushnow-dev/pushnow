import Foundation

@MainActor
protocol JiZhiRepository: Sendable {
    func cachedInbox() -> [InboxItem]?
    func updateCachedInbox(_ event: SecureHistoryEvent)
    func recordItemRead(_ itemID: InboxItem.ID)
    func markItemRead(_ itemID: InboxItem.ID) async throws
    func deleteItem(_ itemID: InboxItem.ID) async throws
    func loadInbox() async throws -> [InboxItem]
    func loadContentModules(for itemID: InboxItem.ID) async throws -> [ContentModule]
    func updateItemState(_ itemID: InboxItem.ID, status: ItemStatusUpdate?, acknowledged: Bool) async throws
    func createReminder(for itemID: InboxItem.ID, input: ReminderCreationInput) async throws
    func loadPersonalSources() async throws -> [SourceChannel]
    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential
    func loadSubscribedChannels() async throws -> [SourceChannel]
    func loadDiscoverChannels() async throws -> [DiscoverChannel]
    func loadReminders() async throws -> [ReminderEntry]
}

extension JiZhiRepository {
    func cachedInbox() -> [InboxItem]? { nil }
    func updateCachedInbox(_ event: SecureHistoryEvent) {}
    func recordItemRead(_ itemID: InboxItem.ID) {}
    func markItemRead(_ itemID: InboxItem.ID) async throws {
        recordItemRead(itemID)
        try await updateItemState(itemID, status: .read, acknowledged: false)
    }
    func deleteItem(_ itemID: InboxItem.ID) async throws {}
}
