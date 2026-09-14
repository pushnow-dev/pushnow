import Foundation
import Security

struct AuthSessionSnapshot: Codable, Equatable, Sendable {
    var session: AuthSession
    var accessToken: String
    var refreshToken: String
    var accessTokenExpiresAt: Date?
}

protocol AuthSessionStoring {
    func load() throws -> AuthSessionSnapshot?
    func save(_ snapshot: AuthSessionSnapshot) throws
    func clear() throws
}

struct KeychainAuthSessionStore: AuthSessionStoring {
    private let service: String
    private let account: String

    init(
        service: String = ServerEnvironment.current.key("com.createitv.pushnow.auth"),
        account: String = "verified-email-session"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> AuthSessionSnapshot? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw keychainError(status)
        }
        guard let data = item as? Data else {
            throw AppError.underlying(AppLocalization.text("Secure storage is unavailable", language: AppLocalization.language))
        }
        return try JSONDecoder().decode(AuthSessionSnapshot.self, from: data)
    }

    func save(_ snapshot: AuthSessionSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try clear()

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw keychainError(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(_ status: OSStatus) -> AppError {
        AppError.underlying(AppLocalization.text("Secure storage is unavailable", language: AppLocalization.language))
    }
}

final class InMemoryAuthSessionStore: AuthSessionStoring {
    private var snapshot: AuthSessionSnapshot?

    init(snapshot: AuthSessionSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() throws -> AuthSessionSnapshot? {
        snapshot
    }

    func save(_ snapshot: AuthSessionSnapshot) throws {
        self.snapshot = snapshot
    }

    func clear() throws {
        snapshot = nil
    }
}
