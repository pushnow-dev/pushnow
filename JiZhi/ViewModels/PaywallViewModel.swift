import Observation
import Foundation

@MainActor
@Observable
final class PaywallViewModel {
    private(set) var state: ViewState<EntitlementState> = .idle
    private(set) var isPending = false
    private var generation = UUID()

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func refresh(service: RevenueCatService) async {
        guard !isLoading else { return }
        let epoch = generation
        state = .loading

        do {
            try await service.refreshCustomerInfo()
            guard epoch == generation else { return }
            isPending = false
            state = .loaded(service.entitlementState)
        } catch {
            guard epoch == generation else { return }
            state = .failed(AppError(error))
        }
    }

    func purchase(plan: MembershipPlan, service: RevenueCatService) async {
        guard !isLoading else { return }
        let epoch = generation
        isPending = false
        state = .loading

        do {
            try await service.purchase(plan: plan)
            guard epoch == generation else { return }
            state = .loaded(service.entitlementState)
        } catch PaymentError.cancelled {
            guard epoch == generation else { return }
            state = .loaded(service.entitlementState)
        } catch PaymentError.pending {
            guard epoch == generation else { return }
            isPending = true
            state = .loaded(service.entitlementState)
        } catch {
            guard epoch == generation else { return }
            state = .failed(AppError(error))
        }
    }

    func restore(service: RevenueCatService) async {
        guard !isLoading else { return }
        let epoch = generation
        state = .loading

        do {
            try await service.restorePurchases()
            guard epoch == generation else { return }
            isPending = false
            state = .loaded(service.entitlementState)
        } catch PaymentError.cancelled {
            guard epoch == generation else { return }
            state = .loaded(service.entitlementState)
        } catch {
            guard epoch == generation else { return }
            state = .failed(AppError(error))
        }
    }

    func redeemCompleted(service: RevenueCatService) async {
        guard !isLoading else { return }
        let epoch = generation
        state = .loading
        do {
            try await service.refreshAfterRedemption()
            guard epoch == generation else { return }
            isPending = false
            state = .loaded(service.entitlementState)
        } catch PaymentError.cancelled {
            guard epoch == generation else { return }
            state = .loaded(service.entitlementState)
        } catch {
            guard epoch == generation else { return }
            state = .failed(AppError(error))
        }
    }

    func reset() {
        generation = UUID()
        isPending = false
        state = .idle
    }
}
