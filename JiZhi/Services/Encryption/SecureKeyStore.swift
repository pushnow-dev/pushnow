import Foundation
import Security

// Each instance captures its namespace so an in-flight operation cannot change stores.
struct SecureKeyStore {
    let environment: ServerEnvironment
    init(environment: ServerEnvironment = .current) { self.environment = environment }

    private func query(_ account: String) -> [String: Any] {
        var result: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: environment.key("com.createitv.pushnow.secure"), kSecAttrAccount as String: account]
        if let group = Bundle.main.object(forInfoDictionaryKey: "SecureKeychainGroup") as? String,
           !group.contains("$(") { result[kSecAttrAccessGroup as String] = group }
        return result
    }

    func read(_ account: String) throws -> Data? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecureFailure.keychain(status) }
        return result as? Data
    }

    func write(_ data: Data?, account: String) throws {
        let request = query(account)
        guard let data else {
            let status = SecItemDelete(request as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureFailure.keychain(status) }
            return
        }
        let update = SecItemUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw SecureFailure.keychain(update) }
        var insertion = request
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insertion as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureFailure.keychain(status) }
    }

    func load(user: String) throws -> SecureLocalKeys? {
        try read("keys:\(user)").map { try JSONDecoder().decode(SecureLocalKeys.self, from: $0) }
    }

    func save(_ keys: SecureLocalKeys) throws {
        try write(JSONEncoder().encode(keys), account: "keys:\(keys.userId)")
    }

    func activate(_ user: String?) throws {
        try write(user.map { Data($0.utf8) }, account: "active-account")
    }

    func active() throws -> SecureLocalKeys? {
        guard let data = try read("active-account"), let user = String(data: data, encoding: .utf8) else { return nil }
        return try load(user: user)
    }

    func claimNotification(_ id: String, keys: SecureLocalKeys) throws -> Bool {
        var request = query("received:\(keys.userId):\(keys.deviceId):\(id)")
        request[kSecValueData as String] = Data([1])
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        if status == errSecDuplicateItem { return false }
        guard status == errSecSuccess else { throw SecureFailure.keychain(status) }
        return true
    }

    func deletedMessageIDs(user: String) throws -> Set<String> {
        var request = query("")
        request.removeValue(forKey: kSecAttrAccount as String)
        request[kSecReturnAttributes as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let records = result as? [[String: Any]] else { throw SecureFailure.keychain(status) }
        let prefix = "deleted:\(user):"
        return Set(records.compactMap { record in
            guard let account = record[kSecAttrAccount as String] as? String, account.hasPrefix(prefix) else { return nil }
            return String(account.dropFirst(prefix.count))
        })
    }
}

// Shared with the notification extension through the existing Keychain access group.
// Production names stay byte-for-byte compatible with existing installations.
enum ServerEnvironment: String, CaseIterable, Identifiable, Sendable {
    case production, sandbox
    var id: String { rawValue }
    var apiURL: URL {
        URL(string: self == .production ? "https://api.pushnow.dev" : "https://sandbox-api.pushnow.dev")!
    }
    func key(_ productionKey: String) -> String {
        self == .production ? productionKey : productionKey + ".sandbox"
    }
    static var current: ServerEnvironment { .production }

    func select() throws {
        try SecureKeyStore(environment: .production).write(Data(Self.production.rawValue.utf8), account: "server-environment")
    }
}
