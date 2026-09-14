import SwiftUI

enum AppRoute: Hashable {
    case featureDetail(id: FeatureItem.ID)

    @MainActor
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .featureDetail(let id):
            Text("项目详情：\(id)")
                .navigationTitle("详情")
        }
    }
}
