import Observation

@MainActor
@Observable
final class PaywallViewModel {
    private(set) var state: ViewState<EntitlementState> = .idle

    func refresh(service: RevenueCatService) async {
        state = .loading

        do {
            try await service.refreshCustomerInfo()
            state = .loaded(service.entitlementState)
        } catch {
            state = .failed(AppError(error))
        }
    }

    func purchase(service: RevenueCatService) async {
        state = .loading

        do {
            try await service.purchaseDefaultPackage()
            state = .loaded(service.entitlementState)
        } catch {
            state = .failed(AppError(error))
        }
    }

    func restore(service: RevenueCatService) async {
        state = .loading

        do {
            try await service.restorePurchases()
            state = .loaded(service.entitlementState)
        } catch {
            state = .failed(AppError(error))
        }
    }
}
