import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case settings

    var id: String { rawValue }

    @MainActor
    @ViewBuilder
    var rootView: some View {
        switch self {
        case .home:
            HomeView()
        case .settings:
            SettingsView()
        }
    }

    @MainActor
    @ViewBuilder
    var label: some View {
        switch self {
        case .home:
            Label("首页", systemImage: "house")
        case .settings:
            Label("设置", systemImage: "gearshape")
        }
    }
}
