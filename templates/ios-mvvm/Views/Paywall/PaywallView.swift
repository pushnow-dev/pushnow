import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = PaywallViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("升级专业版")
                        .font(.largeTitle.bold())

                    Text("解锁高级能力，并保持所有付费权益由 RevenueCat 集中管理。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                entitlementStateView

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.purchase(service: environment.revenueCatService)
                        }
                    } label: {
                        Text("继续购买")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("恢复购买") {
                        Task {
                            await viewModel.restore(service: environment.revenueCatService)
                        }
                    }
                    .buttonStyle(.bordered)

                    legalLinks
                }
            }
            .padding()
            .navigationTitle("专业版")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                if case .idle = viewModel.state {
                    await viewModel.refresh(service: environment.revenueCatService)
                }
            }
        }
    }

    @ViewBuilder
    private var entitlementStateView: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("正在检查权益")
        case .loaded(let entitlement):
            Label(
                entitlement.hasProAccess ? "已拥有专业版权益" : "当前为免费状态",
                systemImage: entitlement.hasProAccess ? "checkmark.seal.fill" : "lock"
            )
        case .failed(let error):
            ErrorStateView(message: error.localizedDescription) {
                Task {
                    await viewModel.refresh(service: environment.revenueCatService)
                }
            }
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        HStack(spacing: 16) {
            if let url = environment.configuration.privacyPolicyURL {
                Link("隐私政策", destination: url)
            }

            if let url = environment.configuration.termsOfUseURL {
                Link("使用条款", destination: url)
            }
        }
        .font(.footnote)
    }
}

#Preview {
    PaywallView()
        .environment(AppEnvironment.preview())
}
