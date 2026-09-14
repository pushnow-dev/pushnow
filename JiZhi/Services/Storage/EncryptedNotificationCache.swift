import CryptoKit
import Foundation

@MainActor
final class EncryptedNotificationCache {
    private static var instances: [ServerEnvironment: EncryptedNotificationCache] = [:]
    static var shared: EncryptedNotificationCache {
        let environment = ServerEnvironment.current
        if let cache = instances[environment] { return cache }
        let cache = EncryptedNotificationCache(environment: environment)
        instances[environment] = cache
        return cache
    }
    let rootURL: URL
    private let keys: any NotificationCacheKeyStoring
    private var loadedKeys: [String: Data] = [:]

    init(rootURL: URL? = nil, keys: (any NotificationCacheKeyStoring)? = nil, environment: ServerEnvironment = .current) {
        self.rootURL = rootURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: environment.key("EncryptedNotifications"), directoryHint: .isDirectory)
        self.keys = keys ?? KeychainNotificationCacheKeys(environment: environment)
    }

    func load<T: Decodable>(_ type: T.Type, user: String, device: String, name: String) throws -> T? {
        guard let data = try read(user: user, device: device, name: name) else { return nil }
        return try JSONDecoder.api.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, user: String, device: String, name: String) throws {
        try write(JSONEncoder.api.encode(value), user: user, device: device, name: name)
    }

    func read(user: String, device: String, name: String) throws -> Data? {
        let file = fileURL(user: user, device: device, name: name)
        guard FileManager.default.fileExists(atPath: file.path),
              let key = try key(user: user, create: false) else { return nil }
        let box = try AES.GCM.SealedBox(combined: Data(contentsOf: file, options: .mappedIfSafe))
        return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad(user: user, device: device, name: name))
    }

    func write(_ data: Data, user: String, device: String, name: String) throws {
        guard let key = try key(user: user, create: true) else { throw SecureFailure.invalid }
        let box = try AES.GCM.seal(data, using: SymmetricKey(data: key), authenticating: aad(user: user, device: device, name: name))
        guard let combined = box.combined else { throw SecureFailure.invalid }
        let file = fileURL(user: user, device: device, name: name)
        var directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try directory.setResourceValues(resources)
        try combined.write(to: file, options: [.atomic, .completeFileProtection])
    }

    func remove(user: String, device: String, name: String) {
        try? FileManager.default.removeItem(at: fileURL(user: user, device: device, name: name))
    }

    func removeAccount(user: String) {
        // Remove the key first so a filesystem cleanup failure cannot reveal old cached content.
        loadedKeys.removeValue(forKey: user)
        try? keys.remove(user: user)
        try? FileManager.default.removeItem(at: rootURL.appending(path: digest(user)))
    }

    func fileURL(user: String, device: String, name: String) -> URL {
        rootURL.appending(path: digest(user)).appending(path: digest(device)).appending(path: digest(name) + ".sealed")
    }

    private func aad(user: String, device: String, name: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [1, "notification-cache", user, device, name])
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func key(user: String, create: Bool) throws -> Data? {
        if let key = loadedKeys[user] { return key }
        if let key = try keys.key(user: user, create: create) {
            loadedKeys[user] = key
            return key
        }
        return nil
    }
}
