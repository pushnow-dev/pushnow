import CryptoKit
import Foundation
import XCTest
@testable import JiZhi

@MainActor
final class EncryptedNotificationCacheTests: XCTestCase {
    func testLogoutClearsTheDefaultAccountCache() throws {
        let user = UUID().uuidString.lowercased()
        let device = UUID().uuidString.lowercased()
        let cache = EncryptedNotificationCache.shared
        defer { cache.removeAccount(user: user) }
        try cache.write(Data("private cached message".utf8), user: user, device: device, name: "inbox")
        let auth = AuthService(apiClient: nil,
            session: AuthSession(userID: user, email: "cache-test@example.com", isVerified: true))
        auth.clearLocalSession()
        XCTAssertNil(auth.session)
        XCTAssertNil(try cache.read(user: user, device: device, name: "inbox"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.fileURL(user: user, device: device, name: "inbox").path))
    }

    func testInboxRoundTripHasNoPlaintextOnDiskAndExcludesBackup() throws {
        let fixture = makeCache()
        defer { fixture.clean() }
        let snapshot = CachedInboxSnapshot(items: [item()], timestamps: [:], savedAt: "2026-09-13T00:00:00Z")
        try fixture.cache.save(snapshot, user: "account-a", device: "device-a", name: "inbox")
        let file = fixture.cache.fileURL(user: "account-a", device: "device-a", name: "inbox")
        let bytes = try Data(contentsOf: file)
        XCTAssertNil(bytes.range(of: Data("Private reminder title".utf8)))
        XCTAssertNil(bytes.range(of: Data("Private reminder body".utf8)))
        let restored = try XCTUnwrap(fixture.cache.load(CachedInboxSnapshot.self, user: "account-a", device: "device-a", name: "inbox"))
        XCTAssertEqual(restored.items, snapshot.items)
        XCTAssertEqual(try file.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let attribute = try FileManager.default.attributesOfItem(atPath: file.path)[.protectionKey]
        let protection = (attribute as? FileProtectionType) ?? (attribute as? String).map(FileProtectionType.init(rawValue:))
        #if targetEnvironment(simulator)
        if let protection { XCTAssertEqual(protection, .complete) }
        #else
        XCTAssertEqual(protection, .complete)
        #endif
    }

    func testCiphertextCannotMoveBetweenAccountsDevicesOrRecordNames() throws {
        let fixture = makeCache()
        defer { fixture.clean() }
        try fixture.cache.write(Data("secret".utf8), user: "a", device: "one", name: "inbox")
        let original = fixture.cache.fileURL(user: "a", device: "one", name: "inbox")
        for scope in [("b", "one", "inbox"), ("a", "two", "inbox"), ("a", "one", "other")] {
            let target = fixture.cache.fileURL(user: scope.0, device: scope.1, name: scope.2)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: original, to: target)
            XCTAssertThrowsError(try fixture.cache.read(user: scope.0, device: scope.1, name: scope.2))
        }
    }

    func testTamperingFailsClosedAndAccountRemovalClearsKeyAndFiles() throws {
        let fixture = makeCache()
        defer { fixture.clean() }
        try fixture.cache.write(Data("secret".utf8), user: "a", device: "one", name: "inbox")
        let file = fixture.cache.fileURL(user: "a", device: "one", name: "inbox")
        var bytes = try Data(contentsOf: file)
        bytes[bytes.count - 1] ^= 1
        try bytes.write(to: file)
        XCTAssertThrowsError(try fixture.cache.read(user: "a", device: "one", name: "inbox"))
        fixture.cache.removeAccount(user: "a")
        XCTAssertTrue(fixture.keys.removed.contains("a"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNil(try fixture.cache.read(user: "a", device: "one", name: "inbox"))
    }

    func testReadAndDeleteEventsPersistWithoutAnActiveInboxView() throws {
        let fixture = makeCache()
        defer { fixture.clean() }
        let snapshot = CachedInboxSnapshot(items: [item()], timestamps: [:], savedAt: "now")
        try fixture.cache.save(snapshot, user: "a", device: "one", name: "inbox")
        try fixture.cache.save(["blob"], user: "a", device: "one", name: "attachments:message")
        try fixture.cache.write(Data([1, 2, 3]), user: "a", device: "one", name: "attachment:message:blob")
        NotificationHistoryCache.apply(SecureHistoryEvent(user: "a", id: "message", deleted: false), device: "one", cache: fixture.cache)
        XCTAssertEqual(try fixture.cache.load(CachedInboxSnapshot.self, user: "a", device: "one", name: "inbox")?.items.first?.unread, false)
        NotificationHistoryCache.apply(SecureHistoryEvent(user: "a", id: "message", deleted: true), device: "one", cache: fixture.cache)
        XCTAssertEqual(try fixture.cache.load(CachedInboxSnapshot.self, user: "a", device: "one", name: "inbox")?.items, [])
        XCTAssertNil(try fixture.cache.read(user: "a", device: "one", name: "attachment:message:blob"))
    }

    private func item() -> InboxItem {
        InboxItem(id: "v2:message", source: "source", category: "encrypted", title: "Private reminder title",
            summary: "Private reminder body", time: "now", icon: "bell", unread: true, priority: .normal,
            reminderBadge: nil, requiresAck: false, pushEnabled: true)
    }

    private func makeCache() -> CacheFixture {
        let url = FileManager.default.temporaryDirectory.appending(path: "cache-test-\(UUID().uuidString)")
        let keys = TestNotificationCacheKeys()
        return CacheFixture(cache: EncryptedNotificationCache(rootURL: url, keys: keys), keys: keys)
    }
}

@MainActor
private struct CacheFixture {
    var cache: EncryptedNotificationCache
    var keys: TestNotificationCacheKeys
    func clean() { try? FileManager.default.removeItem(at: cache.rootURL) }
}

@MainActor
private final class TestNotificationCacheKeys: NotificationCacheKeyStoring {
    let bytes = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    var removed: Set<String> = []
    func key(user: String, create: Bool) throws -> Data? {
        if create { removed.remove(user) }
        return removed.contains(user) ? nil : bytes
    }
    func remove(user: String) throws { removed.insert(user) }
}
