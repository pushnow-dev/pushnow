import CryptoKit
import Foundation
import XCTest
@testable import JiZhi

@MainActor
final class DeletedDetailCacheTests: XCTestCase {
    func testServer404PurgesCachedDetailAndCannotReappearOffline() async throws {
        let store = SecureKeyStore()
        let previousActive = try store.read("active-account")
        let user = UUID().uuidString.lowercased()
        let device = UUID().uuidString.lowercased()
        let id = UUID().uuidString.lowercased()
        let identity = P256.Signing.PrivateKey()
        let agreement = P256.KeyAgreement.PrivateKey()
        let local = SecureLocalKeys(userId: user, deviceId: device, privateKey: agreement.rawRepresentation,
            identityPublicKey: identity.publicKey.x963Representation.base64EncodedString(), identityPrivateKey: identity.rawRepresentation)
        let archiveKey = P256.KeyAgreement.PrivateKey()
        let archiveID = UUID().uuidString.lowercased()
        let archivePublic = archiveKey.publicKey.x963Representation.base64EncodedString()
        let archive = SecureArchive(id: archiveID, publicKey: archivePublic,
            certificate: try SecureCrypto.sign(SecureCrypto.text("archive", user: user, id: archiveID, key: archivePublic), privateKey: identity.rawRepresentation))
        let cache = EncryptedNotificationCache.shared
        defer {
            cache.removeAccount(user: user)
            try? store.write(nil, account: "keys:\(user)")
            try? store.write(nil, account: "archive:\(user)")
            try? store.write(nil, account: "deleted:\(user):\(id)")
            try? store.write(previousActive, account: "active-account")
        }
        try store.save(local)
        try store.activate(user)
        try SecureArchiveService.save(SecureArchiveKeys(archive: archive, privateKey: archiveKey.rawRepresentation), local: local)
        let message = SecureV2Message(messageId: id, userId: user, sourceId: "source", archiveId: archiveID,
            enc: "cached", ciphertext: "cached", sourcePublicKey: "cached", sourceCertificate: "cached")
        let content = SecureV2Content(title: "Deleted private message", body: "Must not return offline", links: [], attachments: [])
        NotificationHistoryCache.saveMessage(message, content: content, local: local)
        NotificationHistoryCache.saveAttachment(Data([1, 2, 3]), id: "blob", message: id, local: local)

        let script = CacheDetailScript(archive: try JSONEncoder.api.encode(ArchiveFixture(archive: archive)))
        let host = UUID().uuidString.lowercased() + ".test"
        CacheDetailProtocol.install(script, host: host)
        defer { CacheDetailProtocol.remove(host: host) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CacheDetailProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = APIClient(baseURL: URL(string: "https://\(host)")!, session: session)
        let sessionStore = InMemoryAuthSessionStore()
        try sessionStore.save(AuthSessionSnapshot(session: AuthSession(userID: user, email: "test@example.com", isVerified: true),
            accessToken: "test-access", refreshToken: "test-refresh", accessTokenExpiresAt: Date(timeIntervalSinceNow: 3600)))
        let auth = AuthService(apiClient: api, sessionStore: sessionStore)
        auth.secureDevices(api: api).keys = local
        XCTAssertNotNil(NotificationHistoryCache.message(id: id, auth: auth))
        do {
            _ = try await SecureV2Inbox.message(id: id, api: api, auth: auth)
            XCTFail("A known 404 must not return cached content")
        } catch let error as APIStatusError { XCTAssertEqual(error.statusCode, 404) }
        XCTAssertNotNil(try store.read("deleted:\(user):\(id)"))
        XCTAssertNil(NotificationHistoryCache.message(id: id, auth: auth))
        XCTAssertNil(try cache.read(user: user, device: device, name: "attachment:\(id):blob"))
        script.goOffline()
        do {
            _ = try await SecureV2Inbox.message(id: id, api: api, auth: auth)
            XCTFail("Offline retry must not resurrect known-deleted content")
        } catch { XCTAssertTrue(NotificationHistoryCache.isOffline(error)) }
    }
}

private struct ArchiveFixture: Encodable { var archive: SecureArchive }

private final class CacheDetailScript: @unchecked Sendable {
    let archive: Data
    private let lock = NSLock()
    private var offline = false
    init(archive: Data) { self.archive = archive }
    func goOffline() { lock.lock(); offline = true; lock.unlock() }
    func response(path: String) throws -> (Int, Data) {
        lock.lock()
        let offline = offline
        lock.unlock()
        if offline { throw URLError(.notConnectedToInternet) }
        return path == "/v2/archive" ? (200, archive) : (404, Data("{}".utf8))
    }
}

private final class CacheDetailProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var scripts: [String: CacheDetailScript] = [:]
    static func install(_ script: CacheDetailScript, host: String) { lock.lock(); scripts[host] = script; lock.unlock() }
    static func remove(host: String) { lock.lock(); scripts.removeValue(forKey: host); lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let script = Self.scripts[request.url?.host ?? ""]
        Self.lock.unlock()
        guard let url = request.url, let script else { client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return }
        do {
            let (status, data) = try script.response(path: url.path)
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
