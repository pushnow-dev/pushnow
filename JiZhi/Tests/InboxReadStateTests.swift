import CryptoKit
import Foundation
import XCTest
@testable import JiZhi

@MainActor
final class InboxReadStateTests: XCTestCase {
    func testAllProtocolsLeaveUnreadButRemainInAll() async {
        let repository = ReadStateRepository()
        repository.response = [readStateItem("legacy"), readStateItem("secure:shared"), readStateItem("v2:shared")]
        let model = InboxViewModel()
        await model.load(repository: repository)
        model.selectedFilter = "未读"
        for id in ["legacy", "secure:shared", "v2:shared"] {
            model.apply(SecureHistoryEvent(user: "user", id: id, deleted: false, itemID: id))
            XCTAssertFalse(model.items.contains { $0.id == id })
        }
        model.selectedFilter = "全部"
        XCTAssertEqual(model.items.count, 3)
        XCTAssertTrue(model.items.allSatisfy { !$0.unread })
        await model.load(repository: repository) // The server still returns unread=true.
        XCTAssertTrue(model.items.allSatisfy { !$0.unread })
    }

    func testReadAndDeleteDuringRefreshKeepNewResultsWithoutResurrection() async {
        let repository = ReadStateRepository()
        repository.response = [readStateItem("legacy"), readStateItem("secure:shared"), readStateItem("v2:deleted")]
        let model = InboxViewModel()
        await model.load(repository: repository)
        repository.suspended = true
        let refresh = Task { await model.load(repository: repository) }
        await repository.waitUntilRequested()
        model.apply(SecureHistoryEvent(user: "user", id: "legacy", deleted: false, itemID: "legacy"))
        model.apply(SecureHistoryEvent(user: "user", id: "shared", deleted: false, itemID: "secure:shared"))
        model.apply(SecureHistoryEvent(user: "user", id: "deleted", deleted: true))
        repository.finish(repository.response + [readStateItem("new")])
        await refresh.value
        XCTAssertEqual(Set(model.items.map(\.id)), ["legacy", "secure:shared", "new"])
        XCTAssertTrue(model.items.filter { $0.id != "new" }.allSatisfy { !$0.unread })
        XCTAssertEqual(model.items.first { $0.id == "new" }?.unread, true)
    }

    func testReadDuringFirstLoadDoesNotDiscardTheLoadAndResetClearsAccountState() async {
        let repository = ReadStateRepository()
        repository.suspended = true
        let model = InboxViewModel()
        let load = Task { await model.load(repository: repository) }
        await repository.waitUntilRequested()
        model.apply(SecureHistoryEvent(user: "user", id: "legacy", deleted: false, itemID: "legacy"))
        repository.finish([readStateItem("legacy"), readStateItem("new")])
        await load.value
        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(model.items.first { $0.id == "legacy" }?.unread, false)
        model.reset()
        repository.suspended = false
        repository.response = [readStateItem("legacy")]
        await model.load(repository: repository)
        XCTAssertEqual(model.items.first?.unread, true)
    }

    func testCachedReadStateSurvivesAStaleServerResponse() async {
        let repository = ReadStateRepository()
        repository.cached = [readStateItem("legacy", unread: false), readStateItem("secure:shared", unread: false)]
        repository.response = [readStateItem("legacy"), readStateItem("secure:shared"), readStateItem("new")]
        let model = InboxViewModel()
        await model.load(repository: repository)
        XCTAssertTrue(model.items.filter { $0.id != "new" }.allSatisfy { !$0.unread })
        XCTAssertEqual(model.items.first { $0.id == "new" }?.unread, true)
    }

    func testSourceFilterUsesMessageSourceCategory() async {
        let repository = ReadStateRepository()
        repository.response = [
            readStateItem("web", sourceKind: "web"),
            readStateItem("cli", sourceKind: "cli"),
            readStateItem("api", sourceType: "webhook"),
            readStateItem("unknown")
        ]
        let model = InboxViewModel()
        await model.load(repository: repository)
        model.selectedFilter = "来源"

        model.selectedSourceFilter = .cli
        XCTAssertEqual(model.items.map(\.id), ["cli"])

        model.selectedSourceFilter = .api
        XCTAssertEqual(model.items.map(\.id), ["api"])

        model.selectedSourceFilter = .all
        XCTAssertEqual(model.items.count, 4)
    }
}

@MainActor
final class ProtocolReadCacheTests: XCTestCase {
    func testLegacyAndV1EventsNeverMutateV2DetailWithTheSameRawID() throws {
        let fixture = ReadCacheFixture()
        defer { fixture.clean() }
        try fixture.cache.save(CachedInboxSnapshot(items: [readStateItem("shared"), readStateItem("secure:shared"),
            readStateItem("v2:shared")], timestamps: [:], savedAt: "now"), user: fixture.user, device: "device", name: "inbox")
        let message = SecureV2Message(messageId: "shared", userId: fixture.user, sourceId: "source", archiveId: "archive",
            enc: "cached", ciphertext: "cached", sourcePublicKey: "cached", sourceCertificate: "cached")
        try fixture.cache.save(CachedSecureMessage(message: message,
            content: SecureV2Content(title: "Title", body: "Body", links: [], attachments: [])),
            user: fixture.user, device: "device", name: "message:shared")
        for id in ["shared", "secure:shared"] {
            NotificationHistoryCache.apply(.init(user: fixture.user, id: "shared", deleted: false, itemID: id),
                device: "device", cache: fixture.cache)
        }
        XCTAssertNil(try fixture.cache.load(CachedSecureMessage.self, user: fixture.user,
            device: "device", name: "message:shared")?.message.readAt)
        let beforeV2 = try XCTUnwrap(fixture.snapshot())
        XCTAssertTrue(beforeV2.items.filter { $0.id != "v2:shared" }.allSatisfy { !$0.unread })
        XCTAssertEqual(beforeV2.items.first { $0.id == "v2:shared" }?.unread, true)
        let event = SecureHistoryEvent(user: fixture.user, id: "shared", deleted: false)
        XCTAssertEqual(event.inboxItemID, "v2:shared")
        NotificationHistoryCache.apply(event, device: "device", cache: fixture.cache)
        XCTAssertNotNil(try fixture.cache.load(CachedSecureMessage.self, user: fixture.user,
            device: "device", name: "message:shared")?.message.readAt)
        XCTAssertTrue(try XCTUnwrap(fixture.snapshot()).items.allSatisfy { !$0.unread })
    }

    func testReconcileRetainsCachedReadsForEveryProtocol() throws {
        let fixture = ReadCacheFixture()
        defer { fixture.clean() }
        let ids = ["legacy", "secure:shared", "v2:shared"]
        try fixture.cache.save(CachedInboxSnapshot(items: ids.map { readStateItem($0, unread: false) },
            timestamps: [:], savedAt: "now"), user: fixture.user, device: "device", name: "inbox")
        let local = SecureLocalKeys(userId: fixture.user, deviceId: "device", privateKey: Data())
        let result = try NotificationHistoryCache.reconcile(ids.map { readStateItem($0) } + [readStateItem("new")],
            local: local, cache: fixture.cache)
        XCTAssertTrue(result.filter { $0.id != "new" }.allSatisfy { !$0.unread })
        XCTAssertEqual(result.first { $0.id == "new" }?.unread, true)
    }

    func testReadBeforeSnapshotSurvivesCacheRecreationAndStaleNetworkResult() throws {
        let fixture = ReadCacheFixture()
        defer { fixture.clean() }
        for id in ["legacy", "secure:shared", "v2:shared"] {
            NotificationHistoryCache.apply(.init(user: fixture.user, id: "shared", deleted: false, itemID: id),
                device: "device", cache: fixture.cache)
        }
        XCTAssertNil(try fixture.snapshot())
        let reopened = EncryptedNotificationCache(rootURL: fixture.cache.rootURL, keys: fixture.keys)
        let incoming = ["legacy", "secure:shared", "v2:shared", "new"].map { readStateItem($0) }
        let local = SecureLocalKeys(userId: fixture.user, deviceId: "device", privateKey: Data())
        let result = try NotificationHistoryCache.reconcile(incoming, local: local, cache: reopened)
        XCTAssertTrue(result.filter { $0.id != "new" }.allSatisfy { !$0.unread })
        XCTAssertEqual(result.first { $0.id == "new" }?.unread, true)
        let otherDevice = SecureLocalKeys(userId: fixture.user, deviceId: "other", privateKey: Data())
        XCTAssertTrue(try NotificationHistoryCache.reconcile(incoming, local: otherDevice, cache: reopened).allSatisfy(\.unread))
        let otherUser = SecureLocalKeys(userId: UUID().uuidString, deviceId: "device", privateKey: Data())
        XCTAssertTrue(try NotificationHistoryCache.reconcile(incoming, local: otherUser, cache: reopened).allSatisfy(\.unread))
        // A stale snapshot saved after the event cannot erase the independent ledger.
        try reopened.save(CachedInboxSnapshot(items: incoming, timestamps: [:], savedAt: "later"),
            user: fixture.user, device: "device", name: "inbox")
        XCTAssertTrue(try NotificationHistoryCache.reconcile(incoming, local: local, cache: reopened)
            .filter { $0.id != "new" }.allSatisfy { !$0.unread })
    }

    func testDefaultV2DeletionKeepsOtherProtocolsAndPurgesAttachments() throws {
        let fixture = ReadCacheFixture()
        defer { fixture.clean() }
        try fixture.cache.save(CachedInboxSnapshot(items: [readStateItem("shared"), readStateItem("secure:shared"),
            readStateItem("v2:shared")], timestamps: ["v2:shared": "now"], savedAt: "now"),
            user: fixture.user, device: "device", name: "inbox")
        try fixture.cache.save(["blob"], user: fixture.user, device: "device", name: "attachments:shared")
        try fixture.cache.write(Data([1]), user: fixture.user, device: "device", name: "attachment:shared:blob")
        NotificationHistoryCache.apply(.init(user: fixture.user, id: "shared", deleted: true),
            device: "device", cache: fixture.cache)
        XCTAssertEqual(Set(try XCTUnwrap(fixture.snapshot()).items.map(\.id)), ["shared", "secure:shared"])
        XCTAssertNil(try fixture.snapshot()?.timestamps["v2:shared"])
        XCTAssertNil(try fixture.cache.read(user: fixture.user, device: "device", name: "attachment:shared:blob"))
    }
}

private func readStateItem(_ id: String, unread: Bool = true, sourceKind: String? = nil,
                           sourceType: String? = nil) -> InboxItem {
    InboxItem(id: id, source: "Source", category: "Category", title: "Title", summary: "Body", time: "now",
        icon: "bell", unread: unread, priority: .normal, reminderBadge: nil, requiresAck: false,
        pushEnabled: true, sourceKind: sourceKind, sourceType: sourceType)
}

@MainActor
private final class ReadStateRepository: JiZhiRepository {
    var response: [InboxItem] = []
    var cached: [InboxItem]?
    var suspended = false
    private var pending: CheckedContinuation<[InboxItem], any Error>?
    private var started: CheckedContinuation<Void, Never>?
    func cachedInbox() -> [InboxItem]? { cached }
    func loadInbox() async throws -> [InboxItem] {
        guard suspended else { return response }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started?.resume(); started = nil
        }
    }
    func waitUntilRequested() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ items: [InboxItem]) { pending?.resume(returning: items); pending = nil }
    func loadContentModules(for itemID: String) async throws -> [ContentModule] { [] }
    func updateItemState(_ itemID: String, status: ItemStatusUpdate?, acknowledged: Bool) async throws {}
    func createReminder(for itemID: String, input: ReminderCreationInput) async throws {}
    func loadPersonalSources() async throws -> [SourceChannel] { [] }
    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential { throw AppError.repositoryUnavailable }
    func loadSubscribedChannels() async throws -> [SourceChannel] { [] }
    func loadDiscoverChannels() async throws -> [DiscoverChannel] { [] }
    func loadReminders() async throws -> [ReminderEntry] { [] }
}

@MainActor
private struct ReadCacheFixture {
    let user = UUID().uuidString
    let keys = ReadCacheKeys()
    let cache: EncryptedNotificationCache
    init() {
        cache = EncryptedNotificationCache(rootURL: FileManager.default.temporaryDirectory
            .appending(path: "read-cache-\(UUID().uuidString)"), keys: keys)
    }
    func snapshot() throws -> CachedInboxSnapshot? {
        try cache.load(CachedInboxSnapshot.self, user: user, device: "device", name: "inbox")
    }
    func clean() { try? FileManager.default.removeItem(at: cache.rootURL) }
}

@MainActor
private final class ReadCacheKeys: NotificationCacheKeyStoring {
    private let bytes = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    func key(user: String, create: Bool) throws -> Data? { bytes }
    func remove(user: String) throws {}
}
