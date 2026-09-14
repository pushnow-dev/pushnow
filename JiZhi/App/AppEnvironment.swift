import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let identity = UUID()
    var isSwitchingServer = false
    let serverEnvironment = ServerEnvironment.current
    let configuration: AppConfiguration
    let repository: any JiZhiRepository
    let authService: AuthService
    let pushRegistrationService: PushRegistrationService
    let revenueCatService: RevenueCatService
    let systemService: SystemService
    let preferences: AppPreferences

    init(
        configuration: AppConfiguration,
        repository: any JiZhiRepository,
        authService: AuthService,
        pushRegistrationService: PushRegistrationService,
        revenueCatService: RevenueCatService,
        systemService: SystemService,
        preferences: AppPreferences = AppPreferences()
    ) {
        self.configuration = configuration
        self.repository = repository
        self.authService = authService
        self.pushRegistrationService = pushRegistrationService
        self.revenueCatService = revenueCatService
        self.systemService = systemService
        self.preferences = preferences
    }

    func switchServer(to target: ServerEnvironment) async throws {
        guard target != serverEnvironment else { return }
        guard !isSwitchingServer, !authService.isVerified else { throw SecureFailure.invalid }
        isSwitchingServer = true
        defer { isSwitchingServer = false }
        // Invalidate pending login/refresh before waiting for RevenueCat's serialized logout.
        try authService.prepareForEnvironmentChange()
        try await revenueCatService.prepareForEnvironmentChange()
        try authService.prepareForEnvironmentChange()
        try target.select()
        pushRegistrationService.stopForEnvironmentChange()
        SecureNotificationRoute.pending = nil
        NotificationCenter.default.post(name: .serverEnvironmentChanged, object: nil)
    }

    static func live() -> AppEnvironment {
        let configuration = AppConfiguration.default
        let apiClient = APIClient(baseURL: configuration.apiBaseURL)
        let authService = makeAuthService(apiClient: apiClient)
        let pushRegistrationService = PushRegistrationService(apiClient: apiClient, authService: authService)
        let revenueCatService = RevenueCatService()
        revenueCatService.reconcileMembership = { [weak authService] userID in
            guard let authService, authService.isVerified, authService.session?.userID == userID else {
                throw PaymentError.accountChanged
            }
            let epoch = authService.generation
            let token = try await authService.requireAccessToken()
            guard authService.generation == epoch, authService.session?.userID == userID else {
                throw PaymentError.accountChanged
            }
            let response: MembershipReconcileResponse = try await apiClient.postJSON(
                "/v1/me/plan/reconcile", body: [String: String](), accessToken: token)
            guard authService.generation == epoch, authService.session?.userID == userID else {
                throw PaymentError.accountChanged
            }
            guard let plan = MembershipPlan(rawValue: response.membership.plan) else {
                throw AppError.repositoryUnavailable
            }
            return plan
        }
        if let apiKey = configuration.revenueCatAPIKey {
            revenueCatService.configure(apiKey: apiKey, userID: authService.isVerified ? authService.session?.userID : nil)
        }
        authService.onAccountChanged = { [weak revenueCatService] userID in
            revenueCatService?.accountChanged(userID: userID)
        }
        Task {
            #if DEBUG
            PaymentDiagnostics.emit(service: revenueCatService, signedIn: authService.isVerified, phase: "started")
            #endif
            do {
                try await revenueCatService.refreshCustomerInfo()
                #if DEBUG
                PaymentDiagnostics.emit(service: revenueCatService, signedIn: authService.isVerified, phase: "completed")
                #endif
            } catch {
                #if DEBUG
                PaymentDiagnostics.emit(service: revenueCatService, signedIn: authService.isVerified, phase: "failed", error: error)
                #endif
            }
        }

        return AppEnvironment(
            configuration: configuration,
            repository: RemoteJiZhiRepository(apiClient: apiClient, authService: authService),
            authService: authService,
            pushRegistrationService: pushRegistrationService,
            revenueCatService: revenueCatService,
            systemService: .live
        )
    }

    static func preview() -> AppEnvironment {
        AppEnvironment(
            configuration: .default,
            repository: PreviewJiZhiRepository(),
            authService: .previewVerified,
            pushRegistrationService: PushRegistrationService(apiClient: nil, authService: .previewVerified),
            revenueCatService: RevenueCatService(entitlementState: .previewPro),
            systemService: .preview
        )
    }

    private static func makeAuthService(apiClient: APIClient) -> AuthService {
        #if DEBUG
        if ["localhost", "127.0.0.1"].contains(apiClient.baseURL.host ?? ""),
           let path = ProcessInfo.processInfo.environment["PUSHNOW_TEST_SESSION_PATH"],
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let snapshot = try? JSONDecoder().decode(AuthSessionSnapshot.self, from: data) {
            return AuthService(apiClient: apiClient, sessionStore: InMemoryAuthSessionStore(snapshot: snapshot))
        }
        #endif
        return AuthService(apiClient: apiClient)
    }
}

extension Notification.Name {
    static let serverEnvironmentChanged = Notification.Name("PushNowServerEnvironmentChanged")
}
