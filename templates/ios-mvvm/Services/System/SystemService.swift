import Foundation

struct SystemService: Sendable {
    let appVersion: String
    let buildNumber: String

    static let live = SystemService(
        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    )

    static let preview = SystemService(
        appVersion: "1.0",
        buildNumber: "1"
    )
}
