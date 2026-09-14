import Foundation

enum MembershipPlan: String, CaseIterable, Identifiable, Sendable {
    case free
    case plus
    case pro

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .free: .app("Free")
        case .plus: .app("Plus")
        case .pro: .app("Pro")
        }
    }

    var dailyNotificationLimit: Int? {
        switch self {
        case .free: 50
        case .plus: 500
        case .pro: nil
        }
    }

    var quotaText: LocalizedStringResource {
        switch self {
        case .free: .app("每天 50 次通知事项")
        case .plus: .app("每天 500 次通知事项")
        case .pro: .app("通知事项不限次数")
        }
    }

    var detailText: LocalizedStringResource {
        switch self {
        case .free: .app("适合个人轻量提醒和测试自动化来源。")
        case .plus: .app("适合稳定接入多个来源和日常高频提醒。")
        case .pro: .app("适合团队、自动化 Agent 和关键任务提醒。")
        }
    }

    var featureTexts: [LocalizedStringResource] {
        switch self {
        case .free:
            [
                .app("邮箱登录和 App 内收件箱"),
                .app("P0/P1/P2 优先级"),
                .app("可选择是否发送 App 推送")
            ]
        case .plus:
            [
                .app("包含免费版全部能力"),
                .app("每天 500 次通知事项"),
                .app("适合多个自动化来源")
            ]
        case .pro:
            [
                .app("包含 Plus 全部能力"),
                .app("通知事项不限次数"),
                .app("适合高频 Agent 和关键任务")
            ]
        }
    }

    var entitlementID: String? {
        switch self {
        case .free: nil
        case .plus: AppConstants.plusEntitlement
        case .pro: AppConstants.defaultEntitlement
        }
    }
}
