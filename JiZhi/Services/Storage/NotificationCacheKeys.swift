import CryptoKit
import Foundation

@MainActor
protocol NotificationCacheKeyStoring {
    func key(user: String, create: Bool) throws -> Data?
    func remove(user: String) throws
}

struct KeychainNotificationCacheKeys: NotificationCacheKeyStoring {
    private let store: SecureKeyStore
    init(environment: ServerEnvironment = .current) { store = SecureKeyStore(environment: environment) }
    func key(user: String, create: Bool) throws -> Data? {
        let account = "notification-cache-key:\(user)"
        if let existing = try store.read(account) {
            guard existing.count == 32 else { throw SecureFailure.invalid }
            return existing
        }
        guard create else { return nil }
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        try store.write(key, account: account)
        return key
    }

    func remove(user: String) throws {
        try store.write(nil, account: "notification-cache-key:\(user)")
    }
}
