import XCTest
@testable import JiZhi

@MainActor
final class JiZhiViewModelTests: XCTestCase {
    func testInboxViewModelLoadsAndFiltersUnreadItems() async {
        let viewModel = InboxViewModel()

        await viewModel.load(repository: PreviewJiZhiRepository())
        viewModel.selectedFilter = "未读"

        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.items.allSatisfy(\.unread))
    }

    func testInboxViewModelFiltersByMessageSource() async {
        let viewModel = InboxViewModel()
        await viewModel.load(repository: SourceFilterTestRepository())

        viewModel.selectedFilter = "来源"
        viewModel.selectedSourceFilter = .cli
        XCTAssertEqual(viewModel.items.map(\.id), ["cli"])

        viewModel.selectedSourceFilter = .api
        XCTAssertEqual(viewModel.items.map(\.id), ["api"])

        viewModel.selectedSourceFilter = .all
        XCTAssertEqual(viewModel.items.count, 4)
    }

    func testInboxDeleteRemovesItemFromCurrentFilter() async {
        let viewModel = InboxViewModel()
        let repository = SourceFilterTestRepository()
        await viewModel.load(repository: repository)

        viewModel.selectedFilter = "来源"
        viewModel.selectedSourceFilter = .cli
        let item = try! XCTUnwrap(viewModel.items.first)

        XCTAssertTrue(await viewModel.delete(item: item, repository: repository))
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(repository.deletedIDs, ["cli"])
    }

    func testEmailAuthCreatesVerifiedPreviewSession() async throws {
        let store = InMemoryAuthSessionStore()
        let service = AuthService(apiClient: nil, sessionStore: store)

        try await service.startEmailLogin(email: "USER@example.com")
        try await service.verifyEmail(code: "123456")

        XCTAssertEqual(service.session?.email, "user@example.com")
        XCTAssertEqual(service.session?.isVerified, true)

        let restoredService = AuthService(apiClient: nil, sessionStore: store)
        XCTAssertEqual(restoredService.session?.email, "user@example.com")
        XCTAssertEqual(restoredService.isVerified, true)
    }

    func testCachedInboxAppearsBeforeNetworkAndFreshResultReplacesIt() async throws {
        let samples = try await PreviewJiZhiRepository().loadInbox()
        let model = InboxViewModel()
        let repository = CachedInboxTestRepository(cached: Array(samples.prefix(1)), result: .success(samples))
        repository.onLoad = { XCTAssertEqual(model.items.count, 1) }
        await model.load(repository: repository)
        XCTAssertEqual(model.items.count, samples.count)
    }

    func testFailedRefreshKeepsCachedNotifications() async throws {
        let samples = try await PreviewJiZhiRepository().loadInbox()
        let model = InboxViewModel()
        let repository = CachedInboxTestRepository(cached: samples, result: .failure(URLError(.notConnectedToInternet)))
        await model.load(repository: repository)
        XCTAssertEqual(model.items.count, samples.count)
        if case .loaded = model.state { } else { XCTFail("Cached inbox should remain visible") }
    }

    func testAccountResetDiscardsInFlightInboxResult() async throws {
        let samples = try await PreviewJiZhiRepository().loadInbox()
        let model = InboxViewModel()
        let repository = CachedInboxTestRepository(cached: samples, result: .success(samples))
        repository.onLoad = { model.reset() }
        await model.load(repository: repository)
        XCTAssertTrue(model.items.isEmpty)
        if case .idle = model.state { } else { XCTFail("Old account must not repopulate the inbox") }
    }

    func testNonNetworkFailureDoesNotKeepCachedNotificationsVisible() async throws {
        let samples = try await PreviewJiZhiRepository().loadInbox()
        let model = InboxViewModel()
        await model.load(repository: CachedInboxTestRepository(cached: samples, result: .failure(AppError.repositoryUnavailable)))
        XCTAssertTrue(model.items.isEmpty)
        if case .failed = model.state { } else { XCTFail("Unexpected failure must not fall back to cache") }
    }

    func testHTTPRefreshFailureKeepsItemsButAuthenticationFailureDoesNot() async throws {
        let samples = try await PreviewJiZhiRepository().loadInbox()
        for status in [400, 422, 429, 503] {
            let model = InboxViewModel()
            await model.load(repository: CachedInboxTestRepository(cached: samples,
                result: .failure(APIStatusError(statusCode: status))))
            XCTAssertEqual(model.items.count, samples.count)
            XCTAssertNotNil(model.refreshError)
            model.reset()
            XCTAssertNil(model.refreshError)
        }
        for status in [401, 403] {
            let model = InboxViewModel()
            await model.load(repository: CachedInboxTestRepository(cached: samples,
                result: .failure(APIStatusError(statusCode: status))))
            XCTAssertTrue(model.items.isEmpty)
            if case .failed = model.state { } else { XCTFail("Access failures must not retain visible history") }
        }
    }
}

@MainActor
private final class CachedInboxTestRepository: JiZhiRepository {
    let cached: [InboxItem]
    let result: Result<[InboxItem], Error>
    var onLoad: (() -> Void)?
    private let preview = PreviewJiZhiRepository()

    init(cached: [InboxItem], result: Result<[InboxItem], Error>) {
        self.cached = cached
        self.result = result
    }

    func cachedInbox() -> [InboxItem]? { cached }
    func loadInbox() async throws -> [InboxItem] { onLoad?(); return try result.get() }
    func loadContentModules(for itemID: String) async throws -> [ContentModule] { try await preview.loadContentModules(for: itemID) }
    func updateItemState(_ itemID: String, status: ItemStatusUpdate?, acknowledged: Bool) async throws { }
    func createReminder(for itemID: String, input: ReminderCreationInput) async throws { }
    func loadPersonalSources() async throws -> [SourceChannel] { [] }
    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential { try await preview.createSource(input) }
    func loadSubscribedChannels() async throws -> [SourceChannel] { [] }
    func loadDiscoverChannels() async throws -> [DiscoverChannel] { [] }
    func loadReminders() async throws -> [ReminderEntry] { [] }
}

@MainActor
private final class SourceFilterTestRepository: JiZhiRepository {
    private(set) var deletedIDs: [String] = []

    func loadInbox() async throws -> [InboxItem] {
        [
            item("web", kind: "web"),
            item("cli", kind: "cli"),
            item("api", sourceType: "webhook"),
            item("unknown")
        ]
    }

    private func item(_ id: String, kind: String? = nil, sourceType: String? = nil) -> InboxItem {
        InboxItem(id: id, source: "Source", category: "Category", title: id, summary: "Body", time: "now",
                  icon: "bell", unread: true, priority: .normal, reminderBadge: nil, requiresAck: false,
                  pushEnabled: true, sourceKind: kind, sourceType: sourceType)
    }

    func loadContentModules(for itemID: String) async throws -> [ContentModule] { [] }
    func updateItemState(_ itemID: String, status: ItemStatusUpdate?, acknowledged: Bool) async throws { }
    func deleteItem(_ itemID: String) async throws { deletedIDs.append(itemID) }
    func createReminder(for itemID: String, input: ReminderCreationInput) async throws { }
    func loadPersonalSources() async throws -> [SourceChannel] { [] }
    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential {
        throw AppError.repositoryUnavailable
    }
    func loadSubscribedChannels() async throws -> [SourceChannel] { [] }
    func loadDiscoverChannels() async throws -> [DiscoverChannel] { [] }
    func loadReminders() async throws -> [ReminderEntry] { [] }
}
