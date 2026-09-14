import Foundation

struct AppConfiguration: Sendable {
    let appName: String
    let minimumOSVersion: String
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let revenueCatAPIKey: String?

    static let `default` = AppConfiguration(
        appName: "TemplateApp",
        minimumOSVersion: "iOS 18.0",
        privacyPolicyURL: URL(string: "https://example.com/privacy"),
        termsOfUseURL: URL(string: "https://example.com/terms"),
        revenueCatAPIKey: nil
    )
}
