import Foundation
import Observation

@MainActor
@Observable
final class RevenueCatService {
    private(set) var entitlementState: EntitlementState
    private(set) var isConfigured: Bool = false
    private(set) var lastError: AppError?

    init(entitlementState: EntitlementState = .empty) {
        self.entitlementState = entitlementState
    }

    func configure(apiKey: String) {
        isConfigured = !apiKey.isEmpty
    }

    func refreshCustomerInfo() async throws {
        guard isConfigured else {
            let error = AppError.paymentNotConfigured
            lastError = error
            throw error
        }
    }

    func purchaseDefaultPackage() async throws {
        guard isConfigured else {
            let error = AppError.paymentNotConfigured
            lastError = error
            throw error
        }
    }

    func restorePurchases() async throws {
        guard isConfigured else {
            let error = AppError.paymentNotConfigured
            lastError = error
            throw error
        }
    }
}
