import XCTest
@testable import JiZhi

@MainActor
final class DiscoverySubscriptionTests: XCTestCase {
    func testScopeRequiresVerifiedNonemptyAccountID() {
        XCTAssertNil(DiscoveryAccountScope(session: nil, generation: UUID()))
        XCTAssertNil(DiscoveryAccountScope(session: session("a", verified: false), generation: UUID()))
        XCTAssertNil(DiscoveryAccountScope(session: session(""), generation: UUID()))
        XCTAssertNotNil(DiscoveryAccountScope(session: session("a"), generation: UUID()))
    }

    func testPreferencesPersistAndStayIsolatedBetweenAccounts() throws {
        try withStore { store, defaults in
            let choice = DiscoverySubscription(channelID: "github", hour: 18, minute: 45, timeZoneID: "Asia/Shanghai")
            try store.save([choice], accountID: "account-a")
            XCTAssertEqual(try DiscoverySubscriptionStore(defaults: defaults).load(accountID: "account-a"), [choice])
            XCTAssertEqual(try store.load(accountID: "account-b"), [])
            try store.save([], accountID: "account-b")
            XCTAssertEqual(try store.load(accountID: "account-a"), [choice])
        }
    }

    func testEditingAndUnsubscribingPersistWithoutChangingOtherChannels() throws {
        try withStore { store, _ in
            let auth = AuthService(apiClient: nil, session: session("account-a"))
            let model = model(auth, store: store)
            model.load()
            XCTAssertTrue(model.save(.init(channelID: "github")))
            XCTAssertTrue(model.save(.init(channelID: "rss")))
            let edit = DiscoverySubscription(channelID: "github", wantsNotification: false,
                hour: 22, minute: 15, timeZoneID: "America/New_York")
            XCTAssertTrue(model.save(edit))
            XCTAssertEqual(model.subscription(for: "github"), edit)
            XCTAssertEqual(try store.load(accountID: "account-a").count, 2)
            XCTAssertTrue(model.unsubscribe(channelID: "github"))
            XCTAssertNil(model.subscription(for: "github"))
            XCTAssertEqual(try store.load(accountID: "account-a").map(\.channelID), ["rss"])
        }
    }

    func testOldEditorCannotSaveAfterLogout() throws {
        try withStore { store, _ in
            let auth = AuthService(apiClient: nil, session: session("subscription-test-a"))
            let model = model(auth, store: store)
            model.load()
            XCTAssertTrue(model.save(.init(channelID: "github")))
            auth.clearLocalSession()
            XCTAssertNil(model.subscription(for: "github"))
            XCTAssertFalse(model.save(.init(channelID: "rss")))
            XCTAssertFalse(model.unsubscribe(channelID: "github"))
            XCTAssertTrue(model.subscriptions.isEmpty)
            XCTAssertEqual(try store.load(accountID: "subscription-test-a").map(\.channelID), ["github"])
        }
    }

    func testDifferentAccountOrStaleGenerationCannotLoadOrWrite() throws {
        try withStore { store, _ in
            try store.save([.init(channelID: "github")], accountID: "a")
            let auth = AuthService(apiClient: nil, session: session("b"))
            let wrongAccount = DiscoveryAccountScope(session: session("a"), generation: auth.generation)!
            let wrongGeneration = DiscoveryAccountScope(session: session("b"), generation: UUID())!
            for scope in [wrongAccount, wrongGeneration] {
                let model = DiscoverySubscriptionsViewModel(auth: auth, scope: scope, store: store)
                model.load()
                XCTAssertFalse(model.loaded)
                XCTAssertTrue(model.subscriptions.isEmpty)
                XCTAssertFalse(model.save(.init(channelID: "rss")))
            }
            XCTAssertEqual(try store.load(accountID: "a").map(\.channelID), ["github"])
            XCTAssertTrue(try store.load(accountID: "b").isEmpty)
        }
    }

    func testCorruptOrMisboundStorageFailsClosed() throws {
        try withStore { store, defaults in
            try store.save([.init(channelID: "github")], accountID: "a")
            defaults.set(defaults.data(forKey: store.storageKey("a")), forKey: store.storageKey("b"))
            XCTAssertThrowsError(try store.load(accountID: "b"))
            defaults.set("corrupt", forKey: store.storageKey("a"))
            let auth = AuthService(apiClient: nil, session: session("a"))
            let model = model(auth, store: store)
            model.load()
            XCTAssertFalse(model.loaded)
            XCTAssertNotNil(model.errorKey)
            XCTAssertFalse(model.save(.init(channelID: "rss")))
            XCTAssertEqual(defaults.string(forKey: store.storageKey("a")), "corrupt")
        }
    }

    func testInvalidTimeTimezoneAndDuplicateChannelsAreRejected() throws {
        try withStore { store, _ in
            for choice in [DiscoverySubscription(channelID: "rss", hour: 24),
                           .init(channelID: "rss", minute: -1),
                           .init(channelID: "rss", timeZoneID: "Invalid/Zone")] {
                XCTAssertThrowsError(try store.save([choice], accountID: "a"))
            }
            let choice = DiscoverySubscription(channelID: "rss")
            XCTAssertThrowsError(try store.save([choice, choice], accountID: "a"))
        }
    }

    func testWallClockRoundTripPreservesSelectedTimezone() {
        var choice = DiscoverySubscription(channelID: "rss", hour: 23, minute: 40, timeZoneID: "Asia/Tokyo")
        let date = choice.pickerDate
        choice.pickerDate = date
        XCTAssertEqual(choice.hour, 23)
        XCTAssertEqual(choice.minute, 40)
        XCTAssertEqual(choice.timeZoneID, "Asia/Tokyo")
    }

    func testConcurrentScreensPreserveEachOthersChannels() throws {
        try withStore { store, _ in
            let auth = AuthService(apiClient: nil, session: session("a"))
            let first = model(auth, store: store)
            let second = model(auth, store: store)
            first.load(); second.load()
            XCTAssertTrue(first.save(.init(channelID: "github")))
            XCTAssertTrue(second.save(.init(channelID: "rss")))
            XCTAssertEqual(Set(try store.load(accountID: "a").map(\.channelID)), ["github", "rss"])
        }
    }

    func testWriteFailureDoesNotReportSavedSubscription() {
        let auth = AuthService(apiClient: nil, session: session("a"))
        let model = model(auth, store: FailingSubscriptionStore())
        model.load()
        XCTAssertFalse(model.save(.init(channelID: "github")))
        XCTAssertNil(model.subscription(for: "github"))
        XCTAssertNotNil(model.errorKey)
    }

    private func session(_ id: String, verified: Bool = true) -> AuthSession {
        AuthSession(userID: id, email: "test@example.com", isVerified: verified)
    }

    private func model(_ auth: AuthService, store: any DiscoverySubscriptionStoring) -> DiscoverySubscriptionsViewModel {
        DiscoverySubscriptionsViewModel(auth: auth,
            scope: DiscoveryAccountScope(session: auth.session, generation: auth.generation)!, store: store)
    }

    private func withStore(_ run: (DiscoverySubscriptionStore, UserDefaults) throws -> Void) rethrows {
        let suite = "discovery-subscription-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try run(DiscoverySubscriptionStore(defaults: defaults), defaults)
    }
}

@MainActor
private struct FailingSubscriptionStore: DiscoverySubscriptionStoring {
    func load(accountID: String) throws -> [DiscoverySubscription] { [] }
    func save(_ subscriptions: [DiscoverySubscription], accountID: String) throws {
        throw DiscoverySubscriptionError.unreadableStorage
    }
}
