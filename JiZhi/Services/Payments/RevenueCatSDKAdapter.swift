import Foundation
import RevenueCat
import StoreKit

@MainActor
final class RevenueCatSDKAdapter: NSObject, PurchaseAdapting, PurchasesDelegate {
    var onCustomerInfoChanged: (() -> Void)?
    private var packages: [String: Package] = [:]
    var userID: String? {
        guard Purchases.isConfigured, !Purchases.shared.isAnonymous else { return nil }
        return Purchases.shared.appUserID
    }

    func configure(apiKey: String, userID: String?) {
        if !Purchases.isConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: apiKey, appUserID: userID)
        }
        Purchases.shared.delegate = self
    }

    func identify(userID: String?) async throws {
        guard self.userID != userID else { return }
        packages = [:]
        if let userID { _ = try await Purchases.shared.logIn(userID) }
        else if !Purchases.shared.isAnonymous { _ = try await Purchases.shared.logOut() }
    }

    func customerInfo() async throws -> EntitlementState {
        try state(await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent))
    }

    func offerings() async throws -> [PurchaseOffer] {
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.all["default"] else { throw PaymentError.catalogUnavailable }
        let mapping: [(MembershipPlan, String, String)] = [
            (.plus, "plus_monthly", "com.createitv.pushnow.plus.monthly"),
            (.pro, "pro_monthly", "com.createitv.pushnow.pro.monthly")
        ]
        var nextPackages: [String: Package] = [:]
        let result: [PurchaseOffer] = mapping.compactMap { plan, identifier, product in
            guard let package = offering.availablePackages.first(where: {
                $0.identifier == identifier && $0.storeProduct.productIdentifier == product
            }) else { return nil }
            nextPackages[identifier] = package
            return PurchaseOffer(plan: plan, packageID: identifier, productID: product,
                localizedPrice: package.storeProduct.localizedPriceString)
        }
        guard !result.isEmpty else { throw PaymentError.catalogUnavailable }
        packages = nextPackages
        return result
    }

    func purchase(packageID: String) async throws -> EntitlementState {
        guard let package = packages[packageID] else { throw PaymentError.unavailable }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { throw PaymentError.cancelled }
            return try state(result.customerInfo)
        } catch {
            throw Self.normalized(error)
        }
    }

    static func normalized(_ error: Error) -> PaymentError {
        if let payment = error as? PaymentError { return payment }
        let value = error as NSError
        if value.domain == NSURLErrorDomain { return .networkUnavailable }
        if value.domain == SKErrorDomain, value.code == SKError.paymentCancelled.rawValue { return .cancelled }
        guard value.domain == ErrorCode.errorDomain else { return .failed }
        switch value.code {
        case ErrorCode.purchaseCancelledError.rawValue: return .cancelled
        case ErrorCode.paymentPendingError.rawValue: return .pending
        case ErrorCode.networkError.rawValue: return .networkUnavailable
        case ErrorCode.configurationError.rawValue: return .catalogUnavailable
        default: return .failed
        }
    }

    func restore() async throws -> EntitlementState {
        try state(await Purchases.shared.restorePurchases())
    }

    func syncPurchases() async throws -> EntitlementState {
        try state(await Purchases.shared.syncPurchases())
    }

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        // Treat callbacks as invalidation signals, never as authority for the active account.
        Task { @MainActor [weak self] in self?.onCustomerInfoChanged?() }
    }

    private func state(_ info: CustomerInfo) throws -> EntitlementState {
        guard info.entitlements.verification != .failed else { throw PaymentError.verificationFailed }
        return EntitlementState(activeEntitlements: Set(info.entitlements.active.keys))
    }
}
