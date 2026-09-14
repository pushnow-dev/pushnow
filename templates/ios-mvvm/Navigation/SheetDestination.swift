import SwiftUI

enum SheetDestination: Identifiable {
    case paywall

    var id: String {
        switch self {
        case .paywall:
            "paywall"
        }
    }

    @MainActor
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .paywall:
            PaywallView()
        }
    }
}
