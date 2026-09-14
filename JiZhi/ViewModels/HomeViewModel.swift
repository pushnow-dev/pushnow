import Foundation
import Observation

@MainActor
@Observable
final class InboxViewModel {
    private(set) var state: ViewState<[InboxItem]> = .idle
    private(set) var refreshError: AppError?
    var selectedFilter = "全部"
    var selectedSourceFilter = HomeSourceFilter.all
    private var requestID = UUID()
    private var accountGeneration: UUID?
    private var loadTask: Task<Void, Never>?
    private var readIDs: Set<String> = []
    private var deletedIDs: Set<String> = []
    private(set) var deletingIDs: Set<String> = []

    var items: [InboxItem] {
        guard case .loaded(let items) = state else { return [] }
        switch selectedFilter {
        case "未读":
            return items.filter(\.unread)
        case "即将提醒":
            return items.filter { $0.reminderBadge != nil }
        case "P0/P1":
            return items.filter { $0.priority == .urgent || $0.priority == .custom }
        case "来源":
            return items.filter { selectedSourceFilter.matches($0) }
        default:
            return items
        }
    }

    func load(repository: any JiZhiRepository, accountGeneration: UUID? = nil) async {
        if let accountGeneration { bindAccount(accountGeneration) }
        guard !Task.isCancelled else { return }
        if let loadTask { await loadTask.value; return }
        let request = UUID()
        requestID = request
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performLoad(repository: repository, request: request)
        }
        loadTask = task
        await task.value
        if requestID == request { loadTask = nil }
    }

    private func performLoad(repository: any JiZhiRepository, request: UUID) async {
        guard !Task.isCancelled, requestID == request else { return }
        requestID = request
        refreshError = nil
        if case .loaded = state { } else if let cached = repository.cachedInbox() {
            state = .loaded(mergingHistory(into: cached))
        } else {
            state = .loading
        }
        do {
            let items = try await repository.loadInbox()
            guard requestID == request, !Task.isCancelled else { return }
            state = .loaded(mergingHistory(into: items))
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--api-diagnostics") {
                print("PUSHNOW_INBOX_LOADED count=\(items.count)")
            }
            #endif
        } catch {
            guard requestID == request else { return }
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                if case .loading = state { state = .idle }
                return
            }
            let status = (error as? APIStatusError)?.statusCode
            let recoverable = NotificationHistoryCache.isOffline(error)
                || status.map { [400, 422, 429].contains($0) || $0 >= 500 } == true
            if case .loaded = state, recoverable, !(error is SecureFailure) {
                refreshError = AppError(error)
                return
            }
            state = .failed(AppError(error))
        }
    }

    func bindAccount(_ generation: UUID) {
        guard accountGeneration != generation else { return }
        reset()
        accountGeneration = generation
    }

    func cancelLoad() {
        requestID = UUID()
        loadTask?.cancel()
        loadTask = nil
        if case .loading = state { state = .idle }
    }

    func reset() {
        cancelLoad()
        state = .idle
        refreshError = nil
        readIDs.removeAll()
        deletedIDs.removeAll()
        deletingIDs.removeAll()
    }

    func apply(_ event: SecureHistoryEvent) {
        if event.deleted { deletedIDs.insert(event.inboxItemID) }
        else { readIDs.insert(event.inboxItemID) }
        guard case .loaded(let items) = state else { return }
        state = .loaded(mergingHistory(into: items))
    }

    func delete(item: InboxItem, repository: any JiZhiRepository) async -> Bool {
        guard !deletingIDs.contains(item.id) else { return false }
        deletingIDs.insert(item.id)
        refreshError = nil
        defer { deletingIDs.remove(item.id) }

        do {
            try await repository.deleteItem(item.id)
            deletedIDs.insert(item.id)
            removeLoadedItem(item.id)
            return true
        } catch {
            refreshError = AppError(error)
            return false
        }
    }

    private func removeLoadedItem(_ itemID: String) {
        guard case .loaded(let items) = state else { return }
        state = .loaded(items.filter { $0.id != itemID })
    }

    private func mergingHistory(into items: [InboxItem]) -> [InboxItem] {
        // Keep acknowledged reads across cached and in-flight stale responses.
        // Do not cancel a refresh: its other, newer items must still be retained.
        readIDs.formUnion(items.filter { !$0.unread }.map(\.id))
        return items.filter { !deletedIDs.contains($0.id) }.map { item in
            var item = item
            if readIDs.contains(item.id) { item.unread = false }
            return item
        }
    }
}

enum HomeSourceFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case web
    case cli
    case api
    case subscription

    var id: String { rawValue }

    var category: MessageSourceCategory? {
        switch self {
        case .all: nil
        case .web: .web
        case .cli: .cli
        case .api: .api
        case .subscription: .subscription
        }
    }

    var localizationKey: String {
        switch self {
        case .all: "All sources"
        case .web: "Web source"
        case .cli: "CLI source"
        case .api: "API source"
        case .subscription: "Subscription source"
        }
    }

    var iconName: String {
        category?.iconName ?? "line.3.horizontal.decrease.circle"
    }

    func localizedTitle(locale: Locale) -> String {
        AppLocalization.text(localizationKey, locale: locale)
    }

    func matches(_ item: InboxItem) -> Bool {
        guard let category else { return true }
        return MessageSourceCategory(kind: item.sourceKind, sourceType: item.sourceType) == category
    }
}

@MainActor
@Observable
final class DetailViewModel {
    private(set) var modules: [ContentModule] = []
    private(set) var isWorking = false
    var errorMessage: String?

    func load(itemID: InboxItem.ID, repository: any JiZhiRepository) async {
        do {
            modules = try await repository.loadContentModules(for: itemID)
            errorMessage = nil
        } catch {
            modules = []
            errorMessage = AppError(error).localizedDescription
        }
    }

    func markKnown(item: InboxItem, repository: any JiZhiRepository) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await repository.updateItemState(item.id, status: .read, acknowledged: item.requiresAck)
            return true
        } catch {
            errorMessage = AppError(error).localizedDescription
            return false
        }
    }

    func delete(item: InboxItem, repository: any JiZhiRepository) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await repository.deleteItem(item.id)
            return true
        } catch {
            errorMessage = AppError(error).localizedDescription
            return false
        }
    }
}

@MainActor
@Observable
final class SourcesViewModel {
    private(set) var personalSources: [SourceChannel] = []
    private(set) var subscriptions: [SourceChannel] = []
    private(set) var createdCredential: CreatedSourceCredential?
    var errorMessage: String?
    var isWorking = false

    func load(repository: any JiZhiRepository) async {
        personalSources = (try? await repository.loadPersonalSources()) ?? []
        subscriptions = (try? await repository.loadSubscribedChannels()) ?? []
    }

    func createSource(_ input: SourceCreationInput, repository: any JiZhiRepository) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let credential = try await repository.createSource(input)
            createdCredential = credential
            personalSources.insert(credential.source, at: 0)
        } catch {
            errorMessage = AppError(error).localizedDescription
        }
    }

    func dismissCreatedCredential() {
        createdCredential = nil
    }
}

@MainActor
@Observable
final class DiscoverViewModel {
    private(set) var channels: [DiscoverChannel] = []
    var selectedFilter = "平台热榜"

    func load(repository: any JiZhiRepository) async {
        channels = (try? await repository.loadDiscoverChannels()) ?? []
    }
}

@MainActor
@Observable
final class RemindersViewModel {
    private(set) var reminders: [ReminderEntry] = []
    var selectedFilter = "即将提醒"

    var activeReminders: [ReminderEntry] {
        reminders.filter { !$0.isCancelled }
    }

    var cancelledReminders: [ReminderEntry] {
        reminders.filter(\.isCancelled)
    }

    func load(repository: any JiZhiRepository) async {
        reminders = (try? await repository.loadReminders()) ?? []
    }
}
