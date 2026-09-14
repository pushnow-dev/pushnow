import Foundation

enum StaticDiscoveryCatalog {
    static let channels: [DiscoverChannel] = [
        .init(id: "weibo", title: "Weibo", summary: "Trending topics and entertainment news", frequency: "Weibo", icon: "flame", badge: "Social"),
        .init(id: "zhihu", title: "Zhihu", summary: "Popular questions and expert discussions", frequency: "Zhihu", icon: "text.bubble", badge: "Questions"),
        .init(id: "bilibili", title: "Bilibili", summary: "Popular videos and creator updates", frequency: "Bilibili", icon: "play.rectangle", badge: "Video"),
        .init(id: "github", title: "GitHub", summary: "Project releases and open-source trends", frequency: "GitHub", icon: "chevron.left.forwardslash.chevron.right", badge: "Development"),
        .init(id: "youtube", title: "YouTube", summary: "Channel videos and creator updates", frequency: "YouTube", icon: "play.rectangle", badge: "Video"),
        .init(id: "telegram", title: "Telegram", summary: "Public channels and community announcements", frequency: "Telegram", icon: "paperplane", badge: "Messaging"),
        .init(id: "rss", title: "RSS", summary: "Blogs, articles and independent publications", frequency: "RSS", icon: "dot.radiowaves.left.and.right", badge: "Feeds"),
        .init(id: "reddit", title: "Reddit", summary: "Community discussions and interest groups", frequency: "Reddit", icon: "bubble.left.and.bubble.right", badge: "Social"),
        .init(id: "hackernews", title: "Hacker News", summary: "Technology, startups and developer discussions", frequency: "Hacker News", icon: "newspaper", badge: "Technology"),
        .init(id: "stackoverflow", title: "Stack Overflow", summary: "Programming questions and technical answers", frequency: "Stack Overflow", icon: "text.bubble", badge: "Development"),
        .init(id: "ai", title: "AI daily picks", summary: "AI research, product launches and industry news", frequency: "AI", icon: "sparkles", badge: "Technology"),
        .init(id: "gold", title: "Gold and silver", summary: "Precious metals, markets and economic updates", frequency: "Markets", icon: "chart.bar", badge: "Finance")
    ]
}

extension DiscoverChannel {
    var discoveryBrand: (asset: String, hex: UInt32)? {
        switch id {
        case "weibo": ("Platform-sinaweibo", 0xE6162D)
        case "zhihu": ("Platform-zhihu", 0x0084FF)
        case "bilibili": ("Platform-bilibili", 0x00A1D6)
        case "github": ("Platform-github", 0x181717)
        case "youtube": ("Platform-youtube", 0xFF0000)
        case "telegram": ("Platform-telegram", 0x26A5E4)
        case "rss": ("Platform-rss", 0xFFA500)
        case "reddit": ("Platform-reddit", 0xFF4500)
        case "hackernews": ("Platform-hackernews", 0xFF6600)
        case "stackoverflow": ("Platform-stackoverflow", 0xF58025)
        default: nil
        }
    }

    func matchesDiscoveryFilter(_ filter: String) -> Bool {
        switch filter {
        case "Trending": ["weibo", "zhihu", "bilibili", "youtube", "reddit"].contains(id)
        case "Daily picks": ["rss", "telegram", "hackernews", "ai"].contains(id)
        case "Prices": id == "gold"
        case "Technology": ["github", "hackernews", "stackoverflow", "ai"].contains(id)
        case "Development": ["github", "stackoverflow", "hackernews", "rss"].contains(id)
        default: true
        }
    }
}

enum DiscoveryCopy {
    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key), bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }
}
