import Foundation
import XCTest
@testable import JiZhi

@MainActor
final class AuthSessionRaceTests: XCTestCase {
    func testAPIErrorReasonsAreDistinctAndDoNotExposeServerText() throws {
        let client = APIClient(baseURL: URL(string: "https://example.test")!)
        let cases: [(Int, String, String)] = [
            (401, "invalid_credentials", "Email or password is incorrect. You can also sign in with a verification code."),
            (401, "session_expired", "Your session has expired. Please sign in again."),
            (401, "auth_code_expired", "The verification code is incorrect or expired. Request a new code."),
            (429, "auth_rate_limited", "Too many requests. Please try again later."),
            (502, "email_delivery_failed", "The verification email could not be sent. Please try again later."),
            (500, "missing_auth_secret", "The service is temporarily unavailable. Please try again later.")
        ]
        for (status, code, expected) in cases {
            let data = try JSONSerialization.data(withJSONObject: ["code": code, "message": "internal secret detail"])
            let response = HTTPURLResponse(url: client.baseURL, statusCode: status, httpVersion: nil, headerFields: nil)!
            XCTAssertThrowsError(try client.validate(response: response, data: data)) { error in
                let api = error as? APIStatusError
                XCTAssertEqual(api?.statusCode, status)
                XCTAssertEqual(api?.messageKey, expected)
                XCTAssertFalse(error.localizedDescription.contains("internal secret detail"))
            }
        }
    }

    func testMalformedAPIErrorUsesStatusFallbackAndSuccessIsUnchanged() throws {
        let client = APIClient(baseURL: URL(string: "https://example.test")!)
        XCTAssertEqual(APIStatusError(statusCode: 403, data: Data("<html>private</html>".utf8)).messageKey,
                       "You do not have permission to perform this action.")
        let response = HTTPURLResponse(url: client.baseURL, statusCode: 204, httpVersion: nil, headerFields: nil)!
        XCTAssertNoThrow(try client.validate(response: response, data: Data()))
    }

    func testRefreshCompletingAfterLogoutCannotRestoreSession() async throws {
        try await checkDelayedResponse(path: "/v1/auth/refresh", sessionResponse: true) {
            try await $0.refreshSession()
        }
    }

    func testCurrentUserCompletingAfterLogoutCannotRestoreSession() async throws {
        try await checkDelayedResponse(path: "/v1/me", sessionResponse: false) {
            try await $0.loadCurrentUser()
        }
    }

    func testPasswordLoginCompletingAfterLogoutCannotRestoreSession() async throws {
        try await checkDelayedResponse(path: "/v1/auth/password/login", sessionResponse: true) {
            try await $0.loginWithPassword(email: "test@example.com", password: "Password2026")
        }
    }

    func testConcurrentExpiredTokenRequestsShareOneRefresh() async throws {
        let started = expectation(description: "One refresh started")
        let secondStarted = expectation(description: "Second caller started")
        let host = UUID().uuidString.lowercased() + ".test"
        let gate = AuthResponseGate(path: "/v1/auth/refresh", started: started)
        DelayedAuthProtocol.install(gate, host: host)
        defer { DelayedAuthProtocol.remove(host: host) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelayedAuthProtocol.self]
        configuration.timeoutIntervalForRequest = 5
        let urlSession = URLSession(configuration: configuration)
        defer { urlSession.invalidateAndCancel() }
        let store = InMemoryAuthSessionStore()
        try store.save(AuthSessionSnapshot(
            session: AuthSession(userID: "test-user", email: "test@example.com", isVerified: true, hasPassword: true),
            accessToken: "old-test-access", refreshToken: "old-test-refresh",
            accessTokenExpiresAt: Date(timeIntervalSinceNow: -60)
        ))
        let service = AuthService(apiClient: APIClient(baseURL: URL(string: "https://\(host)")!, session: urlSession), sessionStore: store)
        let generation = service.generation
        let first = Task { try await service.requireAccessToken() }
        await fulfillment(of: [started], timeout: 5)
        let second = Task {
            secondStarted.fulfill()
            return try await service.requireAccessToken()
        }
        await fulfillment(of: [secondStarted], timeout: 5)
        let response: [String: Any] = [
            "user": ["id": "test-user", "email": "test@example.com", "email_verified_at": "2026-09-12T00:00:00Z", "has_password": true],
            "access_token": "rotated-test-access", "refresh_token": "rotated-test-refresh", "expires_in_seconds": 900
        ]
        gate.resolve(try JSONSerialization.data(withJSONObject: response))
        let firstToken = try await first.value
        let secondToken = try await second.value
        XCTAssertEqual(firstToken, "rotated-test-access")
        XCTAssertEqual(secondToken, firstToken)
        XCTAssertEqual(gate.requestCount, 1)
        XCTAssertEqual(service.generation, generation)
        XCTAssertEqual(try store.load()?.refreshToken, "rotated-test-refresh")
        XCTAssertGreaterThan(try XCTUnwrap(store.load()?.accessTokenExpiresAt), Date())
    }

    private func checkDelayedResponse(
        path: String, sessionResponse: Bool,
        action: @escaping @MainActor (AuthService) async throws -> Void
    ) async throws {
        let started = expectation(description: "Auth request started")
        let host = UUID().uuidString.lowercased() + ".test"
        let gate = AuthResponseGate(path: path, started: started)
        DelayedAuthProtocol.install(gate, host: host)
        defer { DelayedAuthProtocol.remove(host: host) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelayedAuthProtocol.self]
        configuration.timeoutIntervalForRequest = 5
        let urlSession = URLSession(configuration: configuration)
        defer { urlSession.invalidateAndCancel() }
        let store = InMemoryAuthSessionStore()
        try store.save(AuthSessionSnapshot(
            session: AuthSession(userID: "test-user", email: "test@example.com", isVerified: true, hasPassword: true),
            accessToken: "test-access", refreshToken: "test-refresh", accessTokenExpiresAt: Date(timeIntervalSinceNow: 900)
        ))
        let service = AuthService(apiClient: APIClient(baseURL: URL(string: "https://\(host)")!, session: urlSession), sessionStore: store)
        let pending = Task { try await action(service) }
        await fulfillment(of: [started], timeout: 5)
        await service.logout()
        let loggedOutGeneration = service.generation
        let user: [String: Any] = ["id": "test-user", "email": "test@example.com", "email_verified_at": "2026-09-12T00:00:00Z", "has_password": true]
        var response: [String: Any] = ["user": user]
        if sessionResponse {
            response["access_token"] = "new-test-access"
            response["refresh_token"] = "new-test-refresh"
            response["expires_in_seconds"] = 900
        }
        gate.resolve(try JSONSerialization.data(withJSONObject: response))
        if case .success = await pending.result { XCTFail("Stale auth completion must be rejected") }
        XCTAssertNil(service.session)
        XCTAssertNil(service.accessToken)
        XCTAssertNil(service.refreshToken)
        XCTAssertEqual(service.generation, loggedOutGeneration)
        XCTAssertNil(try store.load())
    }
}

private final class AuthResponseGate: @unchecked Sendable {
    let path: String
    let started: XCTestExpectation
    private let lock = NSLock()
    private var pending: URLProtocol?
    private var count = 0
    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return count }

    init(path: String, started: XCTestExpectation) { self.path = path; self.started = started }
    func receive(_ request: URLProtocol) {
        if request.request.url?.path == "/v1/auth/logout" {
            Self.respond(request, data: Data(), status: 204)
        } else if request.request.url?.path == path {
            lock.lock(); pending = request; count += 1; lock.unlock()
            started.fulfill()
        } else {
            request.client?.urlProtocol(request, didFailWithError: URLError(.unsupportedURL))
        }
    }
    func resolve(_ data: Data) {
        lock.lock(); let request = pending; pending = nil; lock.unlock()
        guard let request else { return }
        Self.respond(request, data: data, status: 200)
    }
    private static func respond(_ request: URLProtocol, data: Data, status: Int) {
        let response = HTTPURLResponse(url: request.request.url!, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
        request.client?.urlProtocol(request, didLoad: data)
        request.client?.urlProtocolDidFinishLoading(request)
    }
}

private final class DelayedAuthProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var gates: [String: AuthResponseGate] = [:]
    static func install(_ gate: AuthResponseGate, host: String) {
        lock.lock(); gates[host] = gate; lock.unlock()
    }
    static func remove(host: String) { lock.lock(); gates.removeValue(forKey: host); lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasSuffix(".test") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let gate = Self.gates[request.url?.host ?? ""]; Self.lock.unlock()
        gate?.receive(self)
    }
    override func stopLoading() { }
}
