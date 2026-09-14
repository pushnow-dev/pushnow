import Foundation

struct AppConfiguration: Sendable {
    let appName: String
    let displayName: String
    let minimumOSVersion: String
    let apiBaseURL: URL
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let revenueCatAPIKey: String?

    static var `default`: AppConfiguration { AppConfiguration(
        appName: "PushNow",
        displayName: "PushNow",
        minimumOSVersion: "iOS 18.0",
        apiBaseURL: apiURL,
        privacyPolicyURL: URL(string: "https://pushnow.dev/privacy"),
        termsOfUseURL: URL(string: "https://pushnow.dev/terms"),
        revenueCatAPIKey: revenueCatKey
    ) }

    private static var apiURL: URL {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["PUSHNOW_TEST_API_URL"],
           let url = URL(string: value), ["localhost", "127.0.0.1"].contains(url.host ?? "") { return url }
        #endif
        return ServerEnvironment.current.apiURL
    }

    private static var revenueCatKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              key.hasPrefix("appl_"), key.count > 10 else { return nil }
        return key
    }
}
