import Foundation

struct EntitlementState: Equatable, Sendable {
    var activeEntitlements: Set<String>

    var hasProAccess: Bool {
        activeEntitlements.contains("pro")
    }

    static let empty = EntitlementState(activeEntitlements: [])
    static let previewPro = EntitlementState(activeEntitlements: ["pro"])
}
