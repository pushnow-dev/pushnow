import SwiftUI
import UIKit

struct SourcesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = SourcesViewModel()
    @State private var segment = "我的来源"
    @State private var isPresentingCreateSource = false

    var body: some View {
        VStack(spacing: 0) {
            CompactNavBar(title: "订阅", trailingSystemImage: "plus") {
                if environment.authService.isVerified {
                    isPresentingCreateSource = true
                } else {
                    router.push(.auth)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    segmentedControl
                    if environment.authService.isVerified {
                        personalAccess
                        subscribedList
                    } else {
                        AuthRequiredStateView {
                            router.push(.auth)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .background(JZColor.background)
        .task { await viewModel.load(repository: environment.repository) }
        .sheet(isPresented: $isPresentingCreateSource) {
            NavigationStack {
                SecureSourceEntryView()
            }
        }
        .alert(
            "来源密钥已创建",
            isPresented: Binding(
                get: { viewModel.createdCredential != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissCreatedCredential()
                    }
                }
            )
        ) {
            Button("复制密钥") {
                UIPasteboard.general.string = viewModel.createdCredential?.sourceKey
            }
            Button("知道了", role: .cancel) {
                viewModel.dismissCreatedCredential()
            }
        } message: {
            Text(viewModel.createdCredential?.sourceKey ?? "")
        }
        .onChange(of: environment.authService.isVerified) {
            Task { await viewModel.load(repository: environment.repository) }
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(["我的来源", "发现来源"], id: \.self) { item in
                Button {
                    segment = item
                    if item == "发现来源" { router.selectedTab = .discover }
                } label: {
                    Text(LocalizedStringKey(item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(segment == item ? JZColor.inverseText : JZColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(segment == item ? JZColor.primary : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(JZColor.grouped, in: Capsule())
    }

    private var personalAccess: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("个人接入")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(viewModel.personalSources) { source in
                        SourceCard(source: source)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var subscribedList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已订阅")
                .font(.subheadline.weight(.semibold))
            VStack(spacing: 0) {
                ForEach(viewModel.subscriptions) { source in
                    SourceToggleRow(source: source)
                    if source.id != viewModel.subscriptions.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .jzCardStyle()
        }
    }
}

private struct SourceCard: View {
    let source: SourceChannel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.icon)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                Label(LocalizedStringKey(source.status), systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(JZColor.green)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(JZColor.muted)
        }
        .frame(width: 174)
        .frame(minHeight: 72)
        .jzCardStyle()
    }
}

private struct SourceToggleRow: View {
    let source: SourceChannel
    @State private var isEnabled: Bool

    init(source: SourceChannel) {
        self.source = source
        _isEnabled = State(initialValue: source.isEnabled)
    }

    var body: some View {
        HStack(spacing: 12) {
            SourceIcon(systemName: source.icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                Text(source.subtitle)
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
            }
            Spacer()
            Toggle(source.title, isOn: $isEnabled)
                .labelsHidden()
                .tint(JZColor.blue)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    SourcesView()
        .environment(AppEnvironment.preview())
        .environment(AppRouter())
}
