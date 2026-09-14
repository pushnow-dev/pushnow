import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var isLoggingOut = false
    @State private var isEnablingPush = false

    var body: some View {
        List {
            if let session = environment.authService.session, environment.authService.isVerified {
                Section("Account") {
                    Label(session.email, systemImage: "person.crop.circle.badge.checkmark")
                        .font(.headline).textSelection(.enabled)
                    LabeledContent("邮箱", value: session.email)
                    LabeledContent("用户 ID", value: session.userID).textSelection(.enabled)
                    LabeledContent("登录状态") { Text("已验证").foregroundStyle(JZColor.green) }
                }
                Section("Notifications") {
                    NavigationLink("Devices & Encryption") { DevicesView().localizedNavigationBack() }
                    NavigationLink("Sender keys") { SenderKeysView(device: deviceService).localizedNavigationBack() }
                    NavigationLink("Notification logs") { NotificationLogsView(device: deviceService).localizedNavigationBack() }
                    LabeledContent("App 推送") { Text(environment.pushRegistrationService.state.localizedTitle) }
                    if case .failed(let message) = environment.pushRegistrationService.state {
                        Text(message).font(.footnote).foregroundStyle(JZColor.red)
                    }
                    Button {
                        Task {
                            isEnablingPush = true
                            await environment.pushRegistrationService.enableAfterVerifiedLoginIfPossible()
                            isEnablingPush = false
                        }
                    } label: { Text(pushButtonTitle) }
                    .disabled(isEnablingPush
                        || environment.pushRegistrationService.state == .requestingPermission
                        || environment.pushRegistrationService.state == .registering)
                }
                Section {
                    Button {
                        Task {
                            isLoggingOut = true
                            await environment.authService.logout()
                            environment.pushRegistrationService.handleLogout()
                            isLoggingOut = false
                        }
                    } label: {
                        Text(LocalizedStringKey(isLoggingOut ? "正在退出" : "退出登录"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(JZColor.text)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .disabled(isLoggingOut)
                }
            } else {
                Section("Account") {
                    Label("未登录", systemImage: "person.crop.circle")
                    Button("邮箱登录") { router.push(.auth) }
                }
            }
        }
        .navigationTitle(Text(verbatim: AppLocalization.text("Account", language: environment.preferences.language)))
        .scrollContentBackground(.hidden)
        .background(JZColor.background)
    }

    private var pushButtonTitle: LocalizedStringResource {
        if isEnablingPush { .app("正在启用 App 推送") }
        else if environment.pushRegistrationService.state == .registered { .app("重新绑定 App 推送") }
        else { .app("启用 App 推送") }
    }

    private var deviceService: SecureDeviceService {
        environment.authService.secureDevices(api: APIClient(baseURL: environment.configuration.apiBaseURL))
    }
}
