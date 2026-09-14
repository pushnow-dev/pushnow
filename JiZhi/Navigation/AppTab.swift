import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case inbox
    case sources
    case discover
    case reminders

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .inbox: "首页"
        case .sources: "订阅"
        case .discover: "发现"
        case .reminders: "提醒"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .inbox: .app("首页")
        case .sources: .app("订阅")
        case .discover: .app("发现")
        case .reminders: .app("提醒")
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "house"
        case .sources: "tray"
        case .discover: "safari"
        case .reminders: "bell"
        }
    }

    @MainActor
    @ViewBuilder
    var rootView: some View {
        switch self {
        case .inbox:
            HomeView()
        case .sources:
            SourcesView()
        case .discover:
            DiscoverView()
        case .reminders:
            RemindersView()
        }
    }
}
