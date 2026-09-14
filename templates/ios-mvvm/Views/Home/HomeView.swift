import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HomeViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingStateView(title: "正在加载")
            case .loaded(let items):
                List(items) { item in
                    Button {
                        if item.isProFeature, !environment.revenueCatService.entitlementState.hasProAccess {
                            router.present(.paywall)
                        } else {
                            router.push(.featureDetail(id: item.id))
                        }
                    } label: {
                        FeatureItemRow(item: item)
                    }
                }
                .listStyle(.automatic)
            case .failed(let error):
                ErrorStateView(message: error.localizedDescription) {
                    Task {
                        await viewModel.load(repository: environment.featureRepository)
                    }
                }
            }
        }
        .navigationTitle(environment.configuration.appName)
        .task {
            if case .idle = viewModel.state {
                await viewModel.load(repository: environment.featureRepository)
            }
        }
    }
}

private struct FeatureItemRow: View {
    let item: FeatureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.headline)

                if item.isProFeature {
                    Text("专业版")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            Text(item.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
