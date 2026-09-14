import SwiftUI

struct AuthView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = AuthViewModel()
    @State private var didRequestPushAfterLogin = false
    @FocusState private var focusedField: AuthField?

    var body: some View {
        VStack(spacing: 0) {
            CompactNavBar(title: "邮箱登录", showsBack: true, trailingSystemImage: nil, onBack: router.pop)

            VStack(alignment: .leading, spacing: 22) {
                header
                modePicker
                fields
                submitButton
                statusText
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
        }
        .background(JZColor.background)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bell.badge")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(JZColor.blue)
                .frame(width: 64, height: 64)
                .background(JZColor.grouped, in: .rect(cornerRadius: 16))

            Text("Your notifications, connected")
                .font(.title2.weight(.bold))
                .foregroundStyle(JZColor.text)

            Text("Sign in to keep your messages, devices, and connected sources together.")
                .font(.callout)
                .foregroundStyle(JZColor.muted)
                .lineSpacing(3)
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            TextField("邮箱地址", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .textContentType(.emailAddress)
                .accessibilityIdentifier("auth-email")
                .jzCardStyle()

            if viewModel.phase == .password {
                SecureField("密码", text: $viewModel.password)
                    .textContentType(.password)
                    .accessibilityIdentifier("auth-password")
                    .focused($focusedField, equals: .password)
                    .jzCardStyle()
            }

            if viewModel.phase == .code {
                TextField("6 位验证码", text: $viewModel.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .accessibilityIdentifier("auth-code")
                    .focused($focusedField, equals: .code)
                    .jzCardStyle()
            }

            if viewModel.phase == .setPassword {
                SecureField("设置密码", text: $viewModel.newPassword)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("auth-new-password")
                    .focused($focusedField, equals: .newPassword)
                    .jzCardStyle()

                SecureField("确认密码", text: $viewModel.confirmPassword)
                    .accessibilityIdentifier("auth-confirm-password")
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .jzCardStyle()
            }
        }
    }

    private var modePicker: some View {
        Picker("登录方式", selection: $viewModel.mode) {
            ForEach(AuthMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(viewModel.phase == .setPassword || viewModel.isWorking)
    }

    private var submitButton: some View {
        Button {
            Task {
                switch viewModel.phase {
                case .password:
                    await viewModel.loginWithPassword(service: environment.authService)
                    await completeLoginIfPossible()
                case .email:
                    await viewModel.sendCode(service: environment.authService)
                    focusedField = .code
                case .code:
                    await viewModel.verify(service: environment.authService)
                    if viewModel.needsPasswordSetup {
                        focusedField = .newPassword
                    } else {
                        await completeLoginIfPossible()
                    }
                case .setPassword:
                    await viewModel.setPassword(service: environment.authService)
                    await completeLoginIfPossible()
                case .verified:
                    await completeLoginIfPossible()
                }
            }
        } label: {
            Text(LocalizedStringKey(viewModel.submitTitle))
                .font(.headline.weight(.semibold))
                .foregroundStyle(JZColor.inverseText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(JZColor.primary, in: .rect(cornerRadius: 14))
        }
        .disabled(viewModel.isWorking)
        .accessibilityIdentifier("auth-submit")
    }

    private func completeLoginIfPossible() async {
        guard environment.authService.isVerified, !didRequestPushAfterLogin else {
            return
        }

        didRequestPushAfterLogin = true
        await environment.pushRegistrationService.enableAfterVerifiedLoginIfPossible()
        router.pop()
    }

    @ViewBuilder
    private var statusText: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(JZColor.red)
        } else if viewModel.phase == .code {
            Text("如果邮箱已可用，你会收到一封验证邮件。为了保护隐私，系统不会提示该邮箱是否已注册。")
                .font(.footnote)
                .foregroundStyle(JZColor.muted)
        } else if viewModel.phase == .setPassword {
            Text("邮箱已验证。设置密码后，后续可以直接使用邮箱和密码登录。")
                .font(.footnote)
                .foregroundStyle(JZColor.muted)
        }
    }
}

private enum AuthField {
    case email
    case code
    case password
    case newPassword
    case confirmPassword
}

#Preview {
    AuthView()
        .environment(AppEnvironment.preview())
        .environment(AppRouter())
}
