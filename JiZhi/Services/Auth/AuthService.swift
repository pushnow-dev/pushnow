import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class AuthService {
    private let apiClient: APIClient?
    private let secureKeyStore = SecureKeyStore()
    private let sessionStore: any AuthSessionStoring
    private(set) var session: AuthSession? {
        didSet { onAccountChanged?(session?.isVerified == true ? session?.userID : nil) }
    }
    @ObservationIgnored var onAccountChanged: ((String?) -> Void)?
    private(set) var pendingEmail: String?
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var generation = UUID()
    private var accessTokenExpiresAt: Date?
    @ObservationIgnored private var refreshing: (id: UUID, task: Task<Void, Error>)?
    @ObservationIgnored private var secureDeviceService: SecureDeviceService?

    func secureDevices(api: APIClient) -> SecureDeviceService {
        if let secureDeviceService { return secureDeviceService }
        let value = SecureDeviceService(api: api, auth: self)
        secureDeviceService = value
        return value
    }

    var isVerified: Bool {
        session?.isVerified == true
    }

    init(
        apiClient: APIClient?,
        session: AuthSession? = nil,
        sessionStore: (any AuthSessionStoring)? = nil
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore ?? (apiClient == nil ? InMemoryAuthSessionStore() : KeychainAuthSessionStore())

        if let session {
            self.session = session
        } else if let snapshot = try? self.sessionStore.load() {
            self.session = snapshot.session
            self.accessToken = snapshot.accessToken
            self.refreshToken = snapshot.refreshToken
            self.accessTokenExpiresAt = snapshot.accessTokenExpiresAt
        }
    }

    func startEmailLogin(email: String) async throws {
        pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !pendingEmail.orEmpty.isEmpty else {
            throw AppError.underlying(AppLocalization.text("请输入邮箱", language: AppLocalization.language))
        }

        guard let apiClient else {
            return
        }

        let request = StartEmailAuthRequest(
            email: pendingEmail.orEmpty,
            locale: AppLocalization.locale.identifier,
            timezone: TimeZone.current.identifier,
            client: .current
        )
        let _: StartEmailAuthResponse = try await apiClient.postJSON("/v1/auth/email/start", body: request)
    }

    func verifyEmail(code: String) async throws {
        let requestGeneration = generation
        guard let email = pendingEmail, !email.isEmpty else {
            throw AppError.underlying(AppLocalization.text("请先输入邮箱", language: AppLocalization.language))
        }
        guard code.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6 else {
            throw AppError.underlying(AppLocalization.text("请输入 6 位验证码", language: AppLocalization.language))
        }

        guard let apiClient else {
            session = AuthSession(userID: "local-\(abs(email.hashValue))", email: email, isVerified: true, hasPassword: false)
            accessToken = "preview-access-token"
            refreshToken = "preview-refresh-token"
            persistSessionIfPossible()
            return
        }

        let request = VerifyEmailAuthRequest(
            email: email,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            client: .current
        )
        let response: AuthSessionResponse = try await apiClient.postJSON("/v1/auth/email/verify", body: request)
        guard generation == requestGeneration else { throw SecureFailure.invalid }
        try apply(response: response)
    }

    func loginWithPassword(email: String, password: String) async throws {
        let requestGeneration = generation
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            throw AppError.underlying(AppLocalization.text("请输入邮箱", language: AppLocalization.language))
        }
        guard password.count >= 8 else {
            throw AppError.underlying(AppLocalization.text("请输入密码", language: AppLocalization.language))
        }

        guard let apiClient else {
            session = AuthSession(userID: "local-\(abs(normalizedEmail.hashValue))", email: normalizedEmail, isVerified: true, hasPassword: true)
            accessToken = "preview-access-token"
            refreshToken = "preview-refresh-token"
            persistSessionIfPossible()
            return
        }

        let request = PasswordLoginRequest(email: normalizedEmail, password: password, client: .current)
        let response: AuthSessionResponse = try await apiClient.postJSON("/v1/auth/password/login", body: request)
        guard generation == requestGeneration else { throw SecureFailure.invalid }
        try apply(response: response)
    }

    func setPassword(_ password: String) async throws {
        let requestGeneration = generation
        guard password.count >= 8 else {
            throw AppError.underlying(AppLocalization.text("密码长度至少 8 位", language: AppLocalization.language))
        }
        guard accessToken != nil else {
            throw AppError.underlying(AppLocalization.text("请先验证邮箱", language: AppLocalization.language))
        }

        guard let apiClient else {
            session?.hasPassword = true
            persistSessionIfPossible()
            return
        }

        let token = try await requireAccessToken()
        let response: MeResponse = try await apiClient.postJSON("/v1/me/password", body: SetPasswordRequest(password: password), accessToken: token)
        guard generation == requestGeneration else { throw SecureFailure.invalid }
        session = AuthSession(
            userID: response.user.id,
            email: response.user.email,
            isVerified: response.user.emailVerifiedAt != nil,
            hasPassword: response.user.hasPassword,
            passwordSetAt: response.user.passwordSetAt
        )
        persistSessionIfPossible()
    }

    func refreshSession() async throws {
        if let refreshing { return try await refreshing.task.value }
        let id = UUID()
        let task = Task { try await performRefresh() }
        refreshing = (id, task)
        defer { if refreshing?.id == id { refreshing = nil } }
        try await task.value
    }

    private func performRefresh() async throws {
        let requestGeneration = generation
        guard let apiClient, let refreshToken else {
            throw AppError.underlying(AppLocalization.text("请先登录", language: AppLocalization.language))
        }

        let request = RefreshSessionRequest(refreshToken: refreshToken)
        let response: AuthSessionResponse = try await apiClient.postJSON("/v1/auth/refresh", body: request)
        guard generation == requestGeneration else {
            try? await apiClient.postJSONNoResponse("/v1/auth/logout", body: LogoutRequest(refreshToken: response.refreshToken),
                accessToken: response.accessToken)
            throw SecureFailure.invalid
        }
        guard response.user.id == session?.userID else { throw SecureFailure.invalid }
        try apply(response: response, preservingGeneration: true)
    }

    func loadCurrentUser() async throws {
        let requestGeneration = generation
        guard let apiClient else {
            throw AppError.underlying(AppLocalization.text("请先登录", language: AppLocalization.language))
        }
        let accessToken = try await requireAccessToken()

        let response: MeResponse = try await apiClient.getJSON("/v1/me", accessToken: accessToken)
        guard generation == requestGeneration else { throw SecureFailure.invalid }
        session = AuthSession(
            userID: response.user.id,
            email: response.user.email,
            isVerified: response.user.emailVerifiedAt != nil,
            hasPassword: response.user.hasPassword,
            passwordSetAt: response.user.passwordSetAt
        )
        persistSessionIfPossible()
    }

    func requireAccessToken() async throws -> String {
        guard isVerified else { throw SecureFailure.invalid }
        if apiClient != nil, (accessTokenExpiresAt ?? .distantPast).timeIntervalSinceNow < 60 {
            try await refreshSession()
        }
        guard let accessToken, isVerified else {
            throw AppError.underlying(AppLocalization.text("请先登录邮箱账号", language: AppLocalization.language))
        }
        return accessToken
    }

    func logout() async {
        let logoutToken = accessToken
        let logoutRefreshToken = refreshToken
        clearLocalSession()
        if let apiClient, let logoutToken {
            let request = LogoutRequest(refreshToken: logoutRefreshToken)
            try? await apiClient.postJSONNoResponse("/v1/auth/logout", body: request, accessToken: logoutToken)
        }
    }

    func prepareForEnvironmentChange() throws {
        guard session == nil, accessToken == nil, refreshToken == nil,
              try sessionStore.load() == nil else { throw SecureFailure.invalid }
        generation = UUID()
        refreshing?.task.cancel()
        refreshing = nil
        pendingEmail = nil
        secureDeviceService = nil
        try secureKeyStore.activate(nil)
    }

    func clearLocalSession() {
        generation = UUID()
        if let user = session?.userID { SecureAttachmentService.removeAccountFiles(user: user) }
        if let user = session?.userID { EncryptedNotificationCache.shared.removeAccount(user: user) }
        secureDeviceService = nil
        try? secureKeyStore.activate(nil)
        session = nil
        pendingEmail = nil
        accessToken = nil
        refreshToken = nil
        accessTokenExpiresAt = nil
        try? sessionStore.clear()
    }

    private func apply(response: AuthSessionResponse, preservingGeneration: Bool = false) throws {
        if session?.userID != response.user.id {
            try secureKeyStore.activate(nil)
            if let user = session?.userID { SecureAttachmentService.removeAccountFiles(user: user) }
            if let user = session?.userID { EncryptedNotificationCache.shared.removeAccount(user: user) }
        }
        if !preservingGeneration { generation = UUID() }
        session = AuthSession(
            userID: response.user.id,
            email: response.user.email,
            isVerified: response.user.emailVerifiedAt != nil,
            hasPassword: response.user.hasPassword,
            passwordSetAt: response.user.passwordSetAt
        )
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        accessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(response.expiresInSeconds))
        persistSessionIfPossible()
    }

    private func persistSessionIfPossible() {
        guard let session, let accessToken, let refreshToken else {
            return
        }
        let snapshot = AuthSessionSnapshot(session: session, accessToken: accessToken, refreshToken: refreshToken,
            accessTokenExpiresAt: accessTokenExpiresAt)
        try? sessionStore.save(snapshot)
    }

    static let previewVerified = AuthService(
        apiClient: nil,
        session: .preview,
        sessionStore: InMemoryAuthSessionStore()
    )
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
