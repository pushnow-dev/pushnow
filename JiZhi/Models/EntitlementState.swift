import Foundation

struct EntitlementState: Equatable, Sendable {
    var activeEntitlements: Set<String>

    var hasProAccess: Bool {
        activeEntitlements.contains(AppConstants.defaultEntitlement)
    }

    var membershipPlan: MembershipPlan {
        if activeEntitlements.contains(AppConstants.defaultEntitlement) {
            .pro
        } else if activeEntitlements.contains(AppConstants.plusEntitlement) {
            .plus
        } else {
            .free
        }
    }

    static let empty = EntitlementState(activeEntitlements: [])
    static let previewPro = EntitlementState(activeEntitlements: [AppConstants.defaultEntitlement])
}
