import Foundation

struct FeatureItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let isProFeature: Bool

    static let samples: [FeatureItem] = [
        FeatureItem(
            id: "starter",
            title: "核心功能",
            subtitle: "首版必须完成的主要用户流程",
            isProFeature: false
        ),
        FeatureItem(
            id: "premium",
            title: "高级能力",
            subtitle: "由 RevenueCat 权益控制的付费功能",
            isProFeature: true
        )
    ]
}
