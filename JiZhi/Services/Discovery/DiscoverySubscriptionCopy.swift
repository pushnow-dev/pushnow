import Foundation

enum DiscoverySubscriptionCopy {
    static func text(_ key: String) -> String {
        AppLocalization.text(key, locale: AppLocalization.locale)
    }
}
