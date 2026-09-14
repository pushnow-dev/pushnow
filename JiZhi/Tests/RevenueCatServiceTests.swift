import XCTest
import RevenueCat
@testable import JiZhi

@MainActor
final class RevenueCatServiceTests: XCTestCase {
    private let user = "EA8F113A-73E2-4278-B1D9-E0B821B59B8F"

    func testIdentityUsesBackendMappingAndPricesComeFromOffering() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        try await service.refreshCustomerInfo()
        XCTAssertEqual(adapter.userID, "jizhi_" + user.lowercased())
        XCTAssertEqual(service.price(for: .plus), "$1.49")
        XCTAssertTrue(service.isAvailable(.plus))
        XCTAssertFalse(service.isAvailable(.free))
        XCTAssertFalse(service.isAvailable(.pro))
    }

    func testPurchaseNeverInventsAnEntitlementAndRestoreUsesCustomerInfo() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        try await service.refreshCustomerInfo()
        try await service.purchase(plan: .plus)
        XCTAssertEqual(service.entitlementState, .empty)
        adapter.info = .previewPro
        try await service.restorePurchases()
        XCTAssertEqual(service.entitlementState, .previewPro)
        XCTAssertEqual(adapter.restoreCalls, 1)
    }

    func testCancelIsSilentAndPendingDoesNotUnlock() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        let model = PaywallViewModel()
        try await service.refreshCustomerInfo()
        adapter.purchaseError = .cancelled
        await model.purchase(plan: .plus, service: service)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(service.lastError)
        if case .failed = model.state { XCTFail("Cancellation must not show an error") }
        adapter.purchaseError = .pending
        await model.purchase(plan: .plus, service: service)
        XCTAssertTrue(model.isPending)
        XCTAssertEqual(service.entitlementState, .empty)
        XCTAssertFalse(service.isPurchasing)
        await model.refresh(service: service)
        XCTAssertFalse(model.isPending)
        adapter.purchaseError = .pending
        await model.purchase(plan: .plus, service: service)
        model.reset()
        XCTAssertFalse(model.isPending)
    }

    func testExpiredEntitlementClearsEvenWhenOfferingsFail() async throws {
        let adapter = PaymentTestAdapter()
        adapter.info = .previewPro
        let service = makeService(adapter)
        try await service.refreshCustomerInfo()
        adapter.info = .empty
        adapter.catalogFails = true
        do { try await service.refreshCustomerInfo(); XCTFail("Expected catalog failure") } catch {}
        XCTAssertEqual(service.entitlementState, .empty)
        XCTAssertEqual(service.price(for: .plus), "$1.49")
        XCTAssertTrue(service.isAvailable(.plus))
    }

    func testLogoutRejectsLatePurchaseAndSerializesSDKLogout() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        try await service.refreshCustomerInfo()
        adapter.deferPurchase = true
        let purchase = Task { try await service.purchase(plan: .plus) }
        while adapter.purchaseContinuation == nil { await Task.yield() }
        service.accountChanged(userID: nil)
        XCTAssertEqual(service.entitlementState, .empty)
        XCTAssertFalse(service.isAvailable(.plus))
        adapter.purchaseContinuation?.resume(returning: .previewPro)
        do { try await purchase.value; XCTFail("Late result must be discarded") }
        catch { XCTAssertEqual(error as? PaymentError, .accountChanged) }
        try await service.refreshCustomerInfo()
        XCTAssertNil(adapter.userID)
        XCTAssertEqual(service.entitlementState, .empty)
    }

    func testRedemptionSyncDoesNotGrantWithoutEntitlement() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        try await service.refreshAfterRedemption()
        XCTAssertEqual(adapter.syncCalls, 1)
        XCTAssertEqual(service.entitlementState, .empty)
    }

    func testInvalidKeyAndSignedOutPurchaseAreDisabled() async {
        let adapter = PaymentTestAdapter()
        let service = RevenueCatService(adapter: adapter)
        service.configure(apiKey: "secret_not_a_public_ios_key")
        XCTAssertFalse(service.isConfigured)
        do { try await service.purchase(plan: .plus); XCTFail("Must require login") }
        catch { XCTAssertEqual(error as? PaymentError, .signInRequired) }
        XCTAssertNil(adapter.userID)
    }

    private func makeService(_ adapter: PaymentTestAdapter) -> RevenueCatService {
        let service = RevenueCatService(adapter: adapter)
        service.configure(apiKey: "appl_fake_for_unit_tests_only", userID: user)
        return service
    }

    func testPurchaseRestoreRedemptionAndRefreshReconcileBoundAccount() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        var accounts: [String] = []
        service.reconcileMembership = { account in accounts.append(account); return .free }
        try await service.refreshCustomerInfo()
        try await service.purchase(plan: .plus)
        try await service.restorePurchases()
        try await service.refreshAfterRedemption()
        XCTAssertEqual(accounts, Array(repeating: user, count: 4))
        XCTAssertFalse(service.serverSyncPending)
        XCTAssertEqual(service.serverMembershipPlan, .free)
    }

    func testSuccessfulStoreResultSurvivesFailedReconcileAndRefreshRetries() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        try await service.refreshCustomerInfo()
        adapter.info = .previewPro
        service.reconcileMembership = { _ in throw URLError(.notConnectedToInternet) }
        try await service.purchase(plan: .plus)
        XCTAssertEqual(service.entitlementState, .previewPro)
        XCTAssertTrue(service.serverSyncPending)
        service.reconcileMembership = { _ in .pro }
        try await service.refreshCustomerInfo()
        XCTAssertFalse(service.serverSyncPending)
        XCTAssertEqual(service.serverMembershipPlan, .pro)
    }

    func testSandboxServerPlanMismatchIsNotReportedSynchronized() async throws {
        let adapter = PaymentTestAdapter()
        adapter.info = .previewPro
        let service = makeService(adapter)
        service.reconcileMembership = { _ in .free }
        try await service.refreshAfterRedemption()
        XCTAssertEqual(service.entitlementState, .previewPro)
        XCTAssertEqual(service.serverMembershipPlan, .free)
        XCTAssertTrue(service.serverSyncPending)
    }

    func testLogoutRejectsLateBackendReconciliation() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        var resume: CheckedContinuation<MembershipPlan, Never>?
        service.reconcileMembership = { _ in await withCheckedContinuation { resume = $0 } }
        let refresh = Task { try await service.refreshCustomerInfo() }
        while resume == nil { await Task.yield() }
        service.accountChanged(userID: nil)
        resume?.resume(returning: .pro)
        do { try await refresh.value; XCTFail("Old account result must be rejected") }
        catch { XCTAssertEqual(error as? PaymentError, .accountChanged) }
        XCTAssertNil(service.serverMembershipPlan)
        XCTAssertFalse(service.serverSyncPending)
        XCTAssertEqual(service.entitlementState, .empty)
    }

    func testViewModelResetRejectsLatePurchaseCompletion() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        try await service.refreshCustomerInfo()
        adapter.deferPurchase = true
        let model = PaywallViewModel()
        let action = Task { await model.purchase(plan: .plus, service: service) }
        while adapter.purchaseContinuation == nil { await Task.yield() }
        model.reset()
        service.accountChanged(userID: nil)
        adapter.purchaseContinuation?.resume(returning: .previewPro)
        await action.value
        if case .idle = model.state {} else { XCTFail("Reset view must stay idle") }
    }

    func testSDKConfigurationErrorIsLocalizedWithoutRawURL() {
        let raw = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.configurationError.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "SDK error https://errors.rev.cat/configuring-sdk"])
        let safe = RevenueCatSDKAdapter.normalized(raw)
        XCTAssertEqual(safe, .catalogUnavailable)
        XCTAssertFalse(safe.localizedDescription.contains("https://"))
        XCTAssertEqual(RevenueCatSDKAdapter.normalized(URLError(.timedOut)), .networkUnavailable)
        XCTAssertEqual(RevenueCatSDKAdapter.normalized(NSError(domain: "other", code: 1)), .failed)
    }

    func testCatalogFailureCanRetryAndAccountSwitchClearsOldPrices() async throws {
        let adapter = PaymentTestAdapter()
        let service = makeService(adapter)
        adapter.catalogFails = true
        do { try await service.refreshCustomerInfo(); XCTFail("Expected catalog failure") }
        catch { XCTAssertEqual(error as? PaymentError, .networkUnavailable) }
        XCTAssertFalse(service.isLoading)
        adapter.catalogFails = false
        try await service.refreshCustomerInfo()
        XCTAssertEqual(service.price(for: .plus), "$1.49")
        adapter.catalogFails = true
        do { try await service.refreshCustomerInfo() } catch {}
        XCTAssertEqual(service.price(for: .plus), "$1.49")
        service.accountChanged(userID: nil)
        XCTAssertNil(service.price(for: .plus))
        XCTAssertFalse(service.isAvailable(.plus))
    }
}

@MainActor
private final class PaymentTestAdapter: PurchaseAdapting {
    var userID: String?
    var onCustomerInfoChanged: (() -> Void)?
    var info: EntitlementState = .empty
    var purchaseError: PaymentError?
    var catalogFails = false
    var deferPurchase = false
    var purchaseContinuation: CheckedContinuation<EntitlementState, Never>?
    var restoreCalls = 0
    var syncCalls = 0
    func configure(apiKey: String, userID: String?) { self.userID = userID }
    func identify(userID: String?) async throws { self.userID = userID }
    func customerInfo() async throws -> EntitlementState { info }
    func offerings() async throws -> [PurchaseOffer] {
        if catalogFails { throw URLError(.notConnectedToInternet) }
        return [PurchaseOffer(plan: .plus, packageID: "plus_monthly",
            productID: "com.createitv.pushnow.plus.monthly", localizedPrice: "$1.49")]
    }
    func purchase(packageID: String) async throws -> EntitlementState {
        if let purchaseError { throw purchaseError }
        if deferPurchase { return await withCheckedContinuation { purchaseContinuation = $0 } }
        return info
    }
    func restore() async throws -> EntitlementState { restoreCalls += 1; return info }
    func syncPurchases() async throws -> EntitlementState { syncCalls += 1; return info }
}
