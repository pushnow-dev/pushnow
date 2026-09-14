import Foundation

struct PreviewJiZhiRepository: JiZhiRepository {
    func loadInbox() async throws -> [InboxItem] {
        [
            .init(id: "q2", source: "Research Agent", category: "AI 趋势报告", title: "Q2 竞品分析已完成", summary: "包含报告、表格和 3 个附件", time: "15:12", icon: "doc.text", unread: true, priority: .important, reminderBadge: "5 小时后", requiresAck: true, pushEnabled: true),
            .init(id: "release", source: "GitHub Bot", category: "发布提醒", title: "v2.1.0 版本已发布", summary: "包含 12 条更新内容", time: "13:24", icon: "chevron.left.forwardslash.chevron.right", unread: true, priority: .normal, reminderBadge: nil, requiresAck: false, pushEnabled: true),
            .init(id: "cpu", source: "监控脚本", category: "系统监控", title: "CPU 使用率异常", summary: "服务器 i-7f3d 负载超过 90%", time: "11:03", icon: "bell", unread: true, priority: .urgent, reminderBadge: nil, requiresAck: true, pushEnabled: true),
            .init(id: "news", source: "每日新闻简报", category: "资讯推送", title: "今日重要新闻汇总", summary: "为你整理了 12 条最新资讯", time: "08:20", icon: "newspaper", unread: false, priority: .normal, reminderBadge: nil, requiresAck: false, pushEnabled: false),
            .init(id: "product", source: "产品动态", category: "产品更新", title: "新功能现已上线", summary: "支持自定义提醒规则", time: "昨天 18:45", icon: "shippingbox", unread: false, priority: .custom, reminderBadge: "明天", requiresAck: false, pushEnabled: true)
        ]
    }

    func loadContentModules(for itemID: InboxItem.ID) async throws -> [ContentModule] {
        [
            .init(id: "markdown", icon: "doc.text", title: "Markdown 报告", subtitle: "1.2 MB · 3 天后过期"),
            .init(id: "image", icon: "photo", title: "图表与图片", subtitle: "3 张图片"),
            .init(id: "table", icon: "tablecells", title: "数据表格", subtitle: "Q2 竞品对比.xlsx · 24 KB"),
            .init(id: "link", icon: "link", title: "在线查看完整报告", subtitle: "https://report.example.com"),
            .init(id: "pdf", icon: "doc.richtext", title: "完整报告（PDF）", subtitle: "2.4 MB")
        ]
    }

    func updateItemState(_ itemID: InboxItem.ID, status: ItemStatusUpdate?, acknowledged: Bool) async throws {}

    func createReminder(for itemID: InboxItem.ID, input: ReminderCreationInput) async throws {}

    func loadPersonalSources() async throws -> [SourceChannel] {
        [
            .init(id: "http", title: "HTTP 接入", subtitle: "Webhook · 已启用", icon: "link", status: "已启用", isEnabled: true),
            .init(id: "cli", title: "CLI 接入", subtitle: "Terminal · 已启用", icon: "terminal", status: "已启用", isEnabled: true)
        ]
    }

    func createSource(_ input: SourceCreationInput) async throws -> CreatedSourceCredential {
        let source = SourceChannel(
            id: "preview-\(input.sourceType.rawValue)",
            title: input.name,
            subtitle: "\(input.sourceType.label) · \(input.defaultPushEnabled ? "App 推送" : "仅查看")",
            icon: input.sourceType == .cli ? "terminal" : "link",
            status: "已启用",
            isEnabled: true
        )
        return CreatedSourceCredential(source: source, sourceKey: "jzs_preview_source_key")
    }

    func loadSubscribedChannels() async throws -> [SourceChannel] {
        [
            .init(id: "ai", title: "AI 每日精选", subtitle: "AI · 每日 08:00", icon: "doc.text", status: "已启用", isEnabled: true),
            .init(id: "metals", title: "黄金与白银价格", subtitle: "金融 · 每小时", icon: "chart.bar", status: "已启用", isEnabled: true),
            .init(id: "github", title: "GitHub 发布提醒", subtitle: "开发 · 实时推送", icon: "chevron.left.forwardslash.chevron.right", status: "已启用", isEnabled: true),
            .init(id: "daily", title: "每日新闻简报", subtitle: "资讯 · 每日 08:00", icon: "newspaper", status: "已启用", isEnabled: true),
            .init(id: "product", title: "产品动态", subtitle: "产品 · 实时推送", icon: "shippingbox", status: "仅查看", isEnabled: false)
        ]
    }

    func loadDiscoverChannels() async throws -> [DiscoverChannel] {
        StaticDiscoveryCatalog.channels
    }

    func loadReminders() async throws -> [ReminderEntry] {
        [
            .init(id: "today", day: "今天", time: "20:00", title: "查看研究报告", source: "Research Agent", icon: "doc.text", badge: "还剩 5 小时", priority: .important, isCancelled: false),
            .init(id: "tomorrow", day: "明天", time: "09:30", title: "GitHub 发布提醒", source: "GitHub Bot", icon: "chevron.left.forwardslash.chevron.right", badge: "P0", priority: .urgent, isCancelled: false),
            .init(id: "friday", day: "周五 6月14日", time: "18:00", title: "每周学习总结", source: "个人笔记", icon: "book.closed", badge: "学习", priority: .normal, isCancelled: false),
            .init(id: "cancelled", day: "已取消", time: "6月10日 19:00", title: "产品评审会议", source: "产品团队", icon: "shippingbox", badge: "已取消", priority: .normal, isCancelled: true)
        ]
    }
}
