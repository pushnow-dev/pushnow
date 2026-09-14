import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var code = ""
    var password = ""
    var newPassword = ""
    var confirmPassword = ""
    var mode: AuthMode = .password {
        didSet {
            phase = mode == .password ? .password : .email
            errorMessage = nil
        }
    }
    var phase: AuthPhase = .password
    var errorMessage: String?
    var isWorking = false

    var needsPasswordSetup: Bool {
        phase == .setPassword
    }

    var submitTitle: String {
        switch phase {
        case .password:
            "登录"
        case .email:
            "发送验证邮件"
        case .code:
            "完成验证"
        case .setPassword:
            "设置密码并进入"
        case .verified:
            "完成"
        }
    }

    func sendCode(service: AuthService) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await service.startEmailLogin(email: email)
            phase = .code
        } catch {
            errorMessage = AppError(error).localizedDescription
        }
    }

    func verify(service: AuthService) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await service.verifyEmail(code: code)
            phase = service.session?.hasPassword == true ? .verified : .setPassword
        } catch {
            errorMessage = AppError(error).localizedDescription
        }
    }

    func loginWithPassword(service: AuthService) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await service.loginWithPassword(email: email, password: password)
            phase = .verified
        } catch {
            errorMessage = AppError(error).localizedDescription
        }
    }

    func setPassword(service: AuthService) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        guard newPassword == confirmPassword else {
            errorMessage = AppLocalization.text("两次输入的密码不一致", language: AppLocalization.language)
            return
        }

        do {
            try await service.setPassword(newPassword)
            phase = .verified
        } catch {
            errorMessage = AppError(error).localizedDescription
        }
    }
}

enum AuthPhase {
    case password
    case email
    case code
    case setPassword
    case verified
}

enum AuthMode: String, CaseIterable, Identifiable {
    case password
    case code

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .password: .app("密码登录")
        case .code: .app("邮箱验证")
        }
    }
}
