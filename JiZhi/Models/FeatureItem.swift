import Foundation
import SwiftUI

enum JiZhiPriority: String, CaseIterable, Identifiable, Sendable, Codable {
    case normal = "普通"
    case important = "重要"
    case urgent = "P0"
    case custom = "P1"

    var id: String { rawValue }
    var localizedTitle: String { AppLocalization.text(rawValue, locale: AppLocalization.locale) }

    var tint: Color {
        switch self {
        case .normal: JZColor.muted
        case .important, .custom: JZColor.amber
        case .urgent: JZColor.red
        }
    }

    var background: Color {
        switch self {
        case .normal: JZColor.grouped
        case .important, .custom: JZColor.amberSoft
        case .urgent: JZColor.redSoft
        }
    }
}

struct InboxItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var source: String
    var category: String
    var title: String
    var summary: String
    var time: String
    var icon: String
    var unread: Bool
    var priority: JiZhiPriority
    var reminderBadge: String?
    var requiresAck: Bool
    var pushEnabled: Bool
    var secureIcon: SecureIconContext? = nil
    var receivedAt: String? = nil
    var sourceKind: String? = nil
    var sourceType: String? = nil

    var displayIcon: String {
        icon == "lock.shield" ? "" : icon
    }

}

enum MessageSourceCategory: String, CaseIterable, Identifiable, Sendable {
    case web
    case api
    case cli
    case subscription

    var id: String { rawValue }

    init?(kind: String?, sourceType: String?) {
        if let kind, let category = MessageSourceCategory(rawValue: kind) {
            self = category
            return
        }
        switch sourceType {
        case "cli":
            self = .cli
        case "subscription":
            self = .subscription
        case "webhook":
            self = .api
        default:
            return nil
        }
    }

    var localizationKey: String {
        switch self {
        case .web: "Web source"
        case .api: "API source"
        case .cli: "CLI source"
        case .subscription: "Subscription source"
        }
    }

    var iconName: String {
        switch self {
        case .web: "globe"
        case .api: "network"
        case .cli: "terminal"
        case .subscription: "dot.radiowaves.left.and.right"
        }
    }

    func localizedTitle(locale: Locale) -> String {
        AppLocalization.text(localizationKey, locale: locale)
    }
}

struct ContentModule: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var icon: String
    var title: String
    var subtitle: String
}

struct SourceChannel: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var icon: String
    var status: String
    var isEnabled: Bool
}

struct SourceCreationInput: Equatable, Sendable {
    var name: String
    var sourceType: SourceConnectionType
    var defaultPriority: String
    var defaultPushEnabled: Bool
}

struct CreatedSourceCredential: Equatable, Sendable {
    var source: SourceChannel
    var sourceKey: String
}

enum ItemStatusUpdate: String, Sendable {
    case unread
    case read
    case archived
}

struct ReminderCreationInput: Equatable, Sendable {
    var mode: String
    var scheduledAt: String?
    var timezone: String
    var repeatRule: String?
    var priority: String
    var pushEnabled: Bool
    var requiresAck: Bool
}

enum SourceConnectionType: String, CaseIterable, Identifiable, Sendable {
    case agent
    case cli
    case webhook

    var id: String { rawValue }

    var label: String {
        switch self {
        case .agent: "Agent"
        case .cli: "CLI"
        case .webhook: "Webhook"
        }
    }
}

struct DiscoverChannel: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var summary: String
    var frequency: String
    var icon: String
    var badge: String
}

struct ReminderEntry: Identifiable, Hashable, Sendable {
    let id: String
    var day: String
    var time: String
    var title: String
    var source: String
    var icon: String
    var badge: String?
    var priority: JiZhiPriority
    var isCancelled: Bool
}

struct AuthSession: Codable, Equatable, Sendable {
    var userID: String
    var email: String
    var isVerified: Bool
    var hasPassword: Bool
    var passwordSetAt: String?

    init(userID: String, email: String, isVerified: Bool, hasPassword: Bool = false, passwordSetAt: String? = nil) {
        self.userID = userID
        self.email = email
        self.isVerified = isVerified
        self.hasPassword = hasPassword
        self.passwordSetAt = passwordSetAt
    }

    enum CodingKeys: String, CodingKey {
        case userID
        case email
        case isVerified
        case hasPassword
        case passwordSetAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        email = try container.decode(String.self, forKey: .email)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        hasPassword = try container.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
        passwordSetAt = try container.decodeIfPresent(String.self, forKey: .passwordSetAt)
    }

    static let preview = AuthSession(
        userID: "preview-user",
        email: "user@example.com",
        isVerified: true,
        hasPassword: true,
        passwordSetAt: "2026-09-12T08:00:00.000Z"
    )
}
