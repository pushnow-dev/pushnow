import Foundation
import XCTest
@testable import JiZhi

@MainActor
final class HomeRefreshTests: XCTestCase {
    func testRefreshRequiresVisibleVerifiedForegroundHome() {
        XCTAssertTrue(HomeRefreshSchedule.isEnabled(isForeground: true, isHome: true, isRoot: true, hasSheet: false, isVerified: true))
        for blocked in 0..<5 {
            XCTAssertFalse(HomeRefreshSchedule.isEnabled(isForeground: blocked != 0, isHome: blocked != 1,
                isRoot: blocked != 2, hasSheet: blocked == 3, isVerified: blocked != 4))
        }
        XCTAssertEqual(HomeRefreshSchedule.interval, .seconds(30))
    }

    func testRefreshCompletesBeforeEachDelayAndStopsWhenCancelled() async {
        var events: [String] = []
        await HomeRefreshSchedule.run {
            events.append("start")
            await Task.yield()
            events.append("finish")
        } sleep: {
            events.append("delay")
            if events.count == 6 { throw CancellationError() }
        }
        XCTAssertEqual(events, ["start", "finish", "delay", "start", "finish", "delay"])
    }

    func testConcurrentLoadsShareOneRequestForAccount() async {
        let model = InboxViewModel()
        let repository = RefreshTestRepository()
        let generation = UUID()
        let first = Task { await model.load(repository: repository, accountGeneration: generation) }
        await repository.waitUntilStarted()
        let signal = RefreshStartSignal()
        let second = Task {
            signal.markStarted()
            await model.load(repository: repository, accountGeneration: generation)
        }
        await signal.wait()
        XCTAssertEqual(repository.requests, 1)
        repository.finish([refreshItem("new")])
        await first.value
        await second.value
        XCTAssertEqual(repository.requests, 1)
        XCTAssertEqual(model.items.map(\.id), ["new"])
    }

    func testAccountResetRejectsUncooperativeOldRequest() async {
        let model = InboxViewModel()
        let old = RefreshTestRepository()
        let fresh = RefreshTestRepository()
        let task = Task { await model.load(repository: old, accountGeneration: UUID()) }
        await old.waitUntilStarted()
        let newTask = Task { await model.load(repository: fresh, accountGeneration: UUID()) }
        await fresh.waitUntilStarted()
        fresh.finish([refreshItem("new-account")])
        await newTask.value
        old.finish([refreshItem("old-account")]) // Ignores cancellation on purpose.
        await task.value
        XCTAssertEqual(model.items.map(\.id), ["new-account"])
    }

    func testURLCancellationStaysIdleOrKeepsLoadedHistory() async {
        let model = InboxViewModel()
        let cancelled = RefreshTestRepository()
        cancelled.immediateError = URLError(.cancelled)
        await model.load(repository: cancelled)
        if case .idle = model.state {} else { XCTFail("A cancelled initial request is not a failure") }
        XCTAssertNil(model.refreshError)

        let loaded = RefreshTestRepository()
        let task = Task { await model.load(repository: loaded) }
        await loaded.waitUntilStarted()
        loaded.finish([refreshItem("keep")])
        await task.value
        await model.load(repository: cancelled)
        XCTAssertEqual(model.items.map(\.id), ["keep"])
        XCTAssertNil(model.refreshError)
    }

    func testCancelledRequestDoesNotBecomeErrorOrReplaceHistory() async {
        let model = InboxViewModel()
        let repository = RefreshTestRepository()
        let task = Task { await model.load(repository: repository) }
        await repository.waitUntilStarted()
        model.cancelLoad()
        repository.finish([refreshItem("cancelled")])
        await task.value
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.refreshError)
        if case .idle = model.state {} else { XCTFail("Cancellation should return the initial load to idle") }
    }
}

@MainActor
private final class RefreshStartSignal {
    private var started = false
    private var waiter: CheckedContinuation<Void, Never>?
    func markStarted() { started = true; waiter?.resume(); waiter = nil }
    func wait() async { if !started { await withCheckedContinuation { waiter = $0 } } }
}

@MainActor
private final class RefreshTestRepository: JiZhiRepository {
    private(set) var requests = 0
    var immediateError: Error?
    private var response: CheckedContinuation<[InboxItem], Error>?
    private let started = RefreshStartSignal()
    func loadInbox() async throws -> [InboxItem] {
        requests += 1
        if let immediateError { throw immediateError }
        return try await withCheckedThrowingContinuation {
            response = $0
            started.markStarted()
        }
    }
    func waitUntilStarted() async { await started.wait() }
    func finish(_ items: [InboxItem]) { response?.resume(returning: items); response = nil }
    func loadContentModules(for itemID: String) async throws -> [ContentModule] { [] }
    func updateItemState(_ itemID: String, status: ItemStatusUpdate?, acknowledged: Bool) async throws {}
    func createReminder(for itemID: String, input: ReminderCreationInput) async throws {}
    func loadPersonalSources() async throws -> [SourceChannel] { [] }
    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential { throw AppError.repositoryUnavailable }
    func loadSubscribedChannels() async throws -> [SourceChannel] { [] }
    func loadDiscoverChannels() async throws -> [DiscoverChannel] { [] }
    func loadReminders() async throws -> [ReminderEntry] { [] }
}

private func refreshItem(_ id: String) -> InboxItem {
    InboxItem(id: id, source: "Source", category: "Category", title: "Title", summary: "Body", time: "now",
        icon: "bell", unread: true, priority: .normal, reminderBadge: nil, requiresAck: false, pushEnabled: true)
}
