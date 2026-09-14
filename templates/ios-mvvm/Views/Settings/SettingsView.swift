import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            Section("应用") {
                LabeledContent("名称", value: environment.configuration.appName)
                LabeledContent("最低系统", value: environment.configuration.minimumOSVersion)
                LabeledContent("版本", value: "\(environment.systemService.appVersion) (\(environment.systemService.buildNumber))")
            }

            Section("高级功能") {
                Button("查看专业版") {
                    viewModel.openPaywall()
                    router.present(.paywall)
                }

                LabeledContent("当前权益") {
                    Text(environment.revenueCatService.entitlementState.hasProAccess ? "专业版" : "免费版")
                        .foregroundStyle(environment.revenueCatService.entitlementState.hasProAccess ? .green : .secondary)
                }
            }

            Section("法律") {
                if let url = environment.configuration.privacyPolicyURL {
                    Link("隐私政策", destination: url)
                }

                if let url = environment.configuration.termsOfUseURL {
                    Link("使用条款", destination: url)
                }
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
