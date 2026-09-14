import XCTest
@testable import JiZhi

@MainActor
final class AppPreferencesTests: XCTestCase {
    func testSelectedLanguageLoadsActualTranslatedText() {
        XCTAssertEqual(AppLocalization.text("设置", language: .english), "Settings")
        XCTAssertEqual(AppLocalization.text("设置", language: .simplifiedChinese), "设置")
        XCTAssertEqual(AppLocalization.text("Account", language: .english), "Account")
        XCTAssertEqual(AppLocalization.text("Account", language: .simplifiedChinese), "账号")
        XCTAssertEqual(AppLocalization.text("Light", language: .english), "Light")
        XCTAssertEqual(AppLocalization.text("Light", language: .simplifiedChinese), "浅色")
    }

    func testLocalizedResourcesUseSelectedLanguage() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: AppLocalization.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: AppLocalization.languageKey) }
            else { defaults.removeObject(forKey: AppLocalization.languageKey) }
        }
        defaults.set("en", forKey: AppLocalization.languageKey)
        XCTAssertEqual(String(localized: LocalizedStringResource.app("Account")), "Account")
        defaults.set("zh-Hans", forKey: AppLocalization.languageKey)
        XCTAssertEqual(String(localized: LocalizedStringResource.app("Account")), "账号")
    }
    func testPreferencesDefaultToSystem() {
        withDefaults { defaults in
            let preferences = AppPreferences(defaults: defaults)
            XCTAssertEqual(preferences.language, .system)
            XCTAssertEqual(preferences.appearance, .system)
            XCTAssertNil(preferences.appearance.colorScheme)
        }
    }

    func testLanguageAndAppearancePersistAcrossInstances() {
        withDefaults { defaults in
            let original = AppPreferences(defaults: defaults)
            original.language = .japanese
            original.appearance = .dark
            let restored = AppPreferences(defaults: defaults)
            XCTAssertEqual(restored.language, .japanese)
            XCTAssertEqual(restored.locale.identifier, "ja")
            XCTAssertEqual(restored.appearance, .dark)
            XCTAssertEqual(restored.appearance.colorScheme, .dark)
            restored.language = .system
            restored.appearance = .light
            XCTAssertEqual(AppPreferences(defaults: defaults).language, .system)
            XCTAssertEqual(AppPreferences(defaults: defaults).appearance.colorScheme, .light)
        }
    }

    func testInvalidStoredValuesFallBackToSystem() {
        withDefaults { defaults in
            defaults.set("unsupported", forKey: "pushnow.language")
            defaults.set("unsupported", forKey: "pushnow.appearance")
            XCTAssertEqual(AppPreferences(defaults: defaults).language, .system)
            XCTAssertEqual(AppPreferences(defaults: defaults).appearance, .system)
        }
    }

    private func withDefaults(_ test: (UserDefaults) -> Void) {
        let suite = "pushnow-preferences-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        test(defaults)
    }
}

@MainActor
final class ServerEnvironmentIsolationTests: XCTestCase {
    func testExistingProductionNamesArePreserved() {
        XCTAssertEqual(ServerEnvironment.production.apiURL.absoluteString, "https://api.pushnow.dev")
        XCTAssertEqual(ServerEnvironment.sandbox.apiURL.absoluteString, "https://sandbox-api.pushnow.dev")
        for key in ["com.createitv.pushnow.auth", "com.createitv.pushnow.secure", "pushnow.apnsToken",
                    "EncryptedNotifications", "pushnow-attachments"] {
            XCTAssertEqual(ServerEnvironment.production.key(key), key)
            XCTAssertNotEqual(ServerEnvironment.sandbox.key(key), key)
        }
    }

    func testCurrentEnvironmentAlwaysDefaultsToProduction() throws {
        let store = SecureKeyStore(environment: .production)
        try store.write(Data(ServerEnvironment.sandbox.rawValue.utf8), account: "server-environment")
        defer { try? store.write(nil, account: "server-environment") }
        XCTAssertEqual(ServerEnvironment.current, .production)
        XCTAssertEqual(ServerEnvironment.current.apiURL.absoluteString, "https://api.pushnow.dev")
    }

    func testSameKeyAccountIsIsolatedWithoutChangingSelectedEnvironment() throws {
        let account = "environment-isolation-test:\(UUID().uuidString)"
        let production = SecureKeyStore(environment: .production)
        let sandbox = SecureKeyStore(environment: .sandbox)
        defer {
            try? production.write(nil, account: account)
            try? sandbox.write(nil, account: account)
        }
        try production.write(Data("production secret".utf8), account: account)
        XCTAssertNil(try sandbox.read(account))
        try sandbox.write(Data("sandbox secret".utf8), account: account)
        XCTAssertEqual(try production.read(account), Data("production secret".utf8))
        XCTAssertEqual(try sandbox.read(account), Data("sandbox secret".utf8))
        try sandbox.write(nil, account: account)
        XCTAssertEqual(try production.read(account), Data("production secret".utf8))
    }

    func testCacheAndDiscoveryStaySeparateForIdenticalAccountIDs() throws {
        let suite = "pushnow-environment-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let production = DiscoverySubscriptionStore(defaults: defaults, environment: .production)
        let sandbox = DiscoverySubscriptionStore(defaults: defaults, environment: .sandbox)
        XCTAssertNotEqual(production.storageKey("same-account"), sandbox.storageKey("same-account"))
        defaults.set(Data("invalid production data".utf8), forKey: production.storageKey("same-account"))
        XCTAssertThrowsError(try production.load(accountID: "same-account"))
        XCTAssertEqual(try sandbox.load(accountID: "same-account"), [])
        let productionCache = EncryptedNotificationCache(environment: .production)
        let sandboxCache = EncryptedNotificationCache(environment: .sandbox)
        XCTAssertEqual(productionCache.rootURL.lastPathComponent, "EncryptedNotifications")
        XCTAssertNotEqual(productionCache.fileURL(user: "same", device: "same", name: "same"),
                          sandboxCache.fileURL(user: "same", device: "same", name: "same"))
    }

    func testSignedInSessionCannotPrepareForServerChange() throws {
        let store = InMemoryAuthSessionStore()
        let auth = AuthService(apiClient: nil, session: .preview, sessionStore: store)
        let generation = auth.generation
        XCTAssertThrowsError(try auth.prepareForEnvironmentChange())
        XCTAssertEqual(auth.generation, generation)
        XCTAssertTrue(auth.isVerified)
    }
}
