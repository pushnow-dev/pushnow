import Foundation
import UIKit
import UserNotifications

enum PushRegistrationState: Equatable, Sendable {
    case idle
    case waitingForLogin
    case requestingPermission
    case registering
    case registered
    case denied
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            "未开启"
        case .waitingForLogin:
            "邮箱登录后绑定"
        case .requestingPermission:
            "请求权限中"
        case .registering:
            "注册设备中"
        case .registered:
            "已开启"
        case .denied:
            "系统权限已关闭"
        case .failed(let message):
            message
        }
    }

    var localizedTitle: LocalizedStringResource {
        switch self {
        case .idle:
            .app("未开启")
        case .waitingForLogin:
            .app("邮箱登录后绑定")
        case .requestingPermission:
            .app("请求权限中")
        case .registering:
            .app("注册设备中")
        case .registered:
            .app("已开启")
        case .denied:
            .app("系统权限已关闭")
        case .failed:
            .app("推送注册失败")
        }
    }
}

@MainActor
@Observable
final class PushRegistrationService {
    private let apiClient: APIClient?
    private let authService: AuthService
    private let notificationCenter: NotificationCenter
    private let storedTokenKey = ServerEnvironment.current.key("pushnow.apnsToken")
    private var isActive = true
    private var tokenObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?

    private(set) var state: PushRegistrationState = .idle
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var apnsToken: String?

    init(
        apiClient: APIClient?,
        authService: AuthService,
        notificationCenter: NotificationCenter = .default
    ) {
        self.apiClient = apiClient
        self.authService = authService
        self.notificationCenter = notificationCenter
        self.apnsToken = UserDefaults.standard.string(forKey: storedTokenKey)
        observeAppDelegateCallbacks()
    }

    func stopForEnvironmentChange() {
        isActive = false
        if let tokenObserver { notificationCenter.removeObserver(tokenObserver) }
        if let failureObserver { notificationCenter.removeObserver(failureObserver) }
        tokenObserver = nil
        failureObserver = nil
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus == .denied {
            state = .denied
        }
    }

    func requestPermissionAndRegister() async {
        state = .requestingPermission
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            guard granted else {
                state = .denied
                return
            }
            state = .registering
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            state = .failed(AppError(error).localizedDescription)
        }
    }

    func enableAfterVerifiedLoginIfPossible() async {
        await refreshAuthorizationStatus()
        guard authService.isVerified else {
            state = .waitingForLogin
            return
        }

        if let apiClient {
            do { try await authService.secureDevices(api: apiClient).enroll() }
            catch { state = .failed(AppError(error).localizedDescription); return }
        }

        switch authorizationStatus {
        case .notDetermined:
            await requestPermissionAndRegister()
        case .authorized, .provisional, .ephemeral:
            state = .registering
            UIApplication.shared.registerForRemoteNotifications()
            await bindStoredTokenIfPossible()
        case .denied:
            state = .denied
        @unknown default:
            await bindStoredTokenIfPossible()
        }
    }

    func bindStoredTokenIfPossible() async {
        if authService.isVerified, let apiClient {
            do { try await authService.secureDevices(api: apiClient).enroll() }
            catch { state = .failed(AppError(error).localizedDescription); return }
        }
        guard let apnsToken else {
            await refreshAuthorizationStatus()
            return
        }
        await bindDeviceToken(apnsToken)
    }

    func handleLogout() {
        state = apnsToken == nil ? .idle : .waitingForLogin
    }

    private func observeAppDelegateCallbacks() {
        tokenObserver = notificationCenter.addObserver(
            forName: .didReceiveAPNsToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let tokenData = notification.object as? Data else { return }
            Task { @MainActor [weak self] in
                await self?.handleDeviceToken(tokenData)
            }
        }

        failureObserver = notificationCenter.addObserver(
            forName: .didFailToRegisterForRemoteNotifications,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let error = notification.object as? Error
            Task { @MainActor [weak self] in
                self?.state = .failed(error.map { AppError($0).localizedDescription }
                    ?? AppLocalization.text("设备推送注册失败", language: AppLocalization.language))
            }
        }
    }

    private func handleDeviceToken(_ tokenData: Data) async {
        guard isActive else { return }
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        apnsToken = token
        UserDefaults.standard.set(token, forKey: storedTokenKey)
        await bindDeviceToken(token)
    }

    private func bindDeviceToken(_ token: String) async {
        guard isActive else { return }
        guard authService.isVerified else {
            state = .waitingForLogin
            return
        }
        guard let apiClient else {
            state = .registered
            return
        }

        state = .registering
        do {
            let generation = authService.generation
            let secure = authService.secureDevices(api: apiClient)
            try await secure.enroll()
            guard let deviceID = secure.currentID else { throw SecureFailure.invalid }
            let accessToken = try await authService.requireAccessToken()
            let request = RegisterAPNsTokenRequest(
                token: token,
                environment: PushEnvironment.current.rawValue,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            )
            let _: DeviceResponse = try await apiClient.putJSON(
                "/v1/secure/devices/\(deviceID)/push",
                body: request,
                accessToken: accessToken
            )
            guard authService.generation == generation else { throw SecureFailure.invalid }
            state = .registered
        } catch {
            state = .failed(AppError(error).localizedDescription)
        }
    }
}

private enum PushEnvironment: String {
    case sandbox
    case production

    static var current: PushEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }
}

private struct RegisterAPNsTokenRequest: Encodable {
    var token: String
    var environment: String
    var appVersion: String?
}

private struct RegisterAPNsTokenResponse: Decodable {
    var device: RegisteredDevice
}

private struct RegisteredDevice: Decodable {
    var id: String
    var platform: String
    var enabled: Bool
    var updatedAt: String
}
