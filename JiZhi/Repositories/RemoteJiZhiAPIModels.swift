import Foundation

struct SourcesResponse: Decodable {
    var sources: [APISource]
}

struct SourceResponse: Decodable {
    var source: APISource
}

struct SourceKeyResponse: Decodable {
    var sourceKey: String
}

struct CreateSourceRequest: Encodable {
    var name: String
    var sourceType: String
    var defaultPriority: String
    var defaultPushEnabled: Bool
}

struct CreateSourceKeyRequest: Encodable {
    var scopes: [String]
}

struct ItemsResponse: Decodable {
    var items: [APIItem]
}

struct ItemResponse: Decodable {
    var item: APIItem
}

struct UpdateItemStateRequest: Encodable {
    var status: String?
    var acknowledged: Bool
}

struct CreateReminderRequest: Encodable {
    var mode: String
    var scheduledAt: String?
    var timezone: String
    var repeatRule: String?
    var priority: String
    var pushEnabled: Bool
    var requiresAck: Bool
}

struct ReminderResponse: Decodable {
    var reminder: APIReminder
}

struct RemindersResponse: Decodable {
    var reminders: [APIReminder]
}

struct APISource: Decodable {
    var id: String
    var name: String
    var sourceType: String
    var defaultPriority: String
    var defaultPushEnabled: Bool
    var status: String

    var sourceChannel: SourceChannel {
        SourceChannel(
            id: id,
            title: name,
            subtitle: "\(sourceTypeLabel) · \(contentText(defaultPushEnabled ? "App 推送" : "仅查看"))",
            icon: sourceIcon,
            status: contentText(status == "active" ? "已启用" : "已暂停"),
            isEnabled: status == "active"
        )
    }

    private var sourceTypeLabel: String {
        switch sourceType {
        case "cli": "CLI"
        case "webhook": "Webhook"
        case "subscription": contentText("订阅")
        default: "Agent"
        }
    }

    private var sourceIcon: String {
        switch sourceType {
        case "cli": "terminal"
        case "webhook": "link"
        case "subscription": "dot.radiowaves.left.and.right"
        default: "wand.and.stars"
        }
    }
}

struct APIItem: Decodable {
    var id: String
    var sourceId: String
    var title: String
    var summary: String?
    var status: String
    var priority: String
    var pushEnabled: Bool
    var requiresAck: Bool
    var receivedAt: String

    func inboxItem(sourceName: String, sourceType: String) -> InboxItem {
        InboxItem(
            id: id,
            source: sourceName,
            category: contentText(sourceType == "subscription" ? "订阅来源" : "个人来源"),
            title: title,
            summary: summary ?? contentText(pushEnabled ? "等待查看" : "已保存到 App 内"),
            time: receivedAt.jzRelativeLabel,
            icon: "",
            unread: status == "unread",
            priority: JiZhiPriority(apiValue: priority),
            reminderBadge: contentText(pushEnabled ? "App 推送" : "仅查看"),
            requiresAck: requiresAck,
            pushEnabled: pushEnabled,
            receivedAt: receivedAt,
            sourceType: sourceType
        )
    }

    var contentModules: [ContentModule] {
        [
            ContentModule(id: "summary", icon: "text.alignleft", title: contentText("摘要"), subtitle: summary ?? contentText("暂无摘要")),
            ContentModule(id: "delivery", icon: pushEnabled ? "bell" : "tray", title: contentText(pushEnabled ? "App 推送" : "仅 App 内查看"), subtitle: contentText(requiresAck ? "需要确认收到" : "无需确认")),
            ContentModule(id: "priority", icon: "flag", title: contentText("提醒级别"), subtitle: JiZhiPriority(apiValue: priority).localizedTitle)
        ]
    }
}

struct APIReminder: Decodable {
    var id: String
    var itemId: String
    var mode: String
    var scheduledAt: String?
    var priority: String
    var pushEnabled: Bool
    var status: String
    var nextFireAt: String?

    func entry(item: APIItem?, source: APISource?) -> ReminderEntry {
        ReminderEntry(
            id: id,
            day: (nextFireAt ?? scheduledAt ?? "").jzDayLabel,
            time: (nextFireAt ?? scheduledAt ?? "").jzTimeLabel,
            title: item?.title ?? contentText("提醒事项"),
            source: source?.name ?? "Agent",
            icon: "",
            badge: pushEnabled ? JiZhiPriority(apiValue: priority).localizedTitle : contentText("仅查看"),
            priority: JiZhiPriority(apiValue: priority),
            isCancelled: status == "cancelled" || mode == "in_app_only"
        )
    }
}

extension JiZhiPriority {
    init(apiValue: String) {
        switch apiValue.lowercased() {
        case "p0", "urgent", "紧急":
            self = .urgent
        case "p1":
            self = .custom
        case "important", "重要":
            self = .important
        default:
            self = .normal
        }
    }
}

extension String {
    var jzRelativeLabel: String {
        AppTimestamp.relative(self)
    }

    var jzDayLabel: String {
        guard let date = AppTimestamp.parse(self) else { return contentText("Time not set") }
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.timeZone = AppTimestamp.zone(UserDefaults.standard.string(forKey: AppTimestamp.timezoneKey) ?? "system")
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    var jzTimeLabel: String {
        guard let date = AppTimestamp.parse(self) else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.timeZone = AppTimestamp.zone(UserDefaults.standard.string(forKey: AppTimestamp.timezoneKey) ?? "system")
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private func contentText(_ key: String) -> String {
    AppLocalization.text(key, locale: AppLocalization.locale)
}
