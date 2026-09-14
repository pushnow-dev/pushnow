import Foundation

struct MembershipReconcileResponse: Decodable {
    let membership: Status
    struct Status: Decodable { let plan: String }
}

struct PurchaseOffer: Equatable, Sendable {
    let plan: MembershipPlan
    let packageID: String
    let productID: String
    let localizedPrice: String
}

enum PaymentError: Error, Equatable, LocalizedError, Sendable {
    case cancelled
    case pending
    case unavailable
    case signInRequired
    case accountChanged
    case busy
    case verificationFailed
    case catalogUnavailable
    case networkUnavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .cancelled: AppLocalization.text("Purchase cancelled", language: AppLocalization.language)
        case .pending: AppLocalization.text("Purchase awaiting approval", language: AppLocalization.language)
        case .unavailable: AppLocalization.text("This plan is currently unavailable", language: AppLocalization.language)
        case .signInRequired: AppLocalization.text("Sign in before purchasing", language: AppLocalization.language)
        case .accountChanged: AppLocalization.text("Your account changed. Please try again.", language: AppLocalization.language)
        case .busy: AppLocalization.text("A purchase is already in progress", language: AppLocalization.language)
        case .verificationFailed: AppLocalization.text("Purchase verification failed", language: AppLocalization.language)
        case .catalogUnavailable: AppLocalization.text("Subscriptions are temporarily unavailable. Please try again.", language: AppLocalization.language)
        case .networkUnavailable: AppLocalization.text("Cannot connect to the App Store. Check your connection and try again.", language: AppLocalization.language)
        case .failed: AppLocalization.text("The payment request could not be completed. Please try again.", language: AppLocalization.language)
        }
    }
}

@MainActor
protocol PurchaseAdapting: AnyObject {
    var userID: String? { get }
    var onCustomerInfoChanged: (() -> Void)? { get set }
    func configure(apiKey: String, userID: String?)
    func identify(userID: String?) async throws
    func customerInfo() async throws -> EntitlementState
    func offerings() async throws -> [PurchaseOffer]
    func purchase(packageID: String) async throws -> EntitlementState
    func restore() async throws -> EntitlementState
    func syncPurchases() async throws -> EntitlementState
}
