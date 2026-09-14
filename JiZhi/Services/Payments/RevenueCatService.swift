import Foundation
import Observation

@MainActor
@Observable
final class RevenueCatService {
    private let serverEnvironment = ServerEnvironment.current
    private(set) var entitlementState: EntitlementState
    private(set) var isConfigured = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var lastError: AppError?
    private(set) var offers: [PurchaseOffer] = []
    private(set) var serverSyncPending = false
    private(set) var serverMembershipPlan: MembershipPlan?
    @ObservationIgnored var reconcileMembership: ((String) async throws -> MembershipPlan)?
    @ObservationIgnored private let adapter: any PurchaseAdapting
    @ObservationIgnored private var tail: Task<Void, Error>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var desiredUserID: String?
    @ObservationIgnored private var pendingOperations = 0

    init(entitlementState: EntitlementState = .empty, adapter: (any PurchaseAdapting)? = nil) {
        self.entitlementState = entitlementState
        self.adapter = adapter ?? RevenueCatSDKAdapter()
    }

    func configure(apiKey: String, userID: String? = nil) {
        guard !isConfigured, apiKey.hasPrefix("appl_"), apiKey.count > 10 else { return }
        desiredUserID = userID
        adapter.configure(apiKey: apiKey, userID: userID.map(self.environmentUserID))
        isConfigured = true
        adapter.onCustomerInfoChanged = { [weak self] in
            guard let self, !isLoading, desiredUserID != nil else { return }
            Task { try? await self.refreshCustomerInfo() }
        }
    }

    // Displayed access is invalidated immediately; SDK identity operations run in order.
    func accountChanged(userID: String?) {
        guard userID != desiredUserID else { return }
        generation = UUID()
        desiredUserID = userID
        entitlementState = .empty
        offers = []
        lastError = nil
        serverSyncPending = false
        serverMembershipPlan = nil
        guard isConfigured else { return }
        Task { try? await self.refreshCustomerInfo() }
    }

    func prepareForEnvironmentChange() async throws {
        guard !isPurchasing else { throw PaymentError.busy }
        accountChanged(userID: nil)
        if isConfigured { try await refreshCustomerInfo() }
        adapter.onCustomerInfoChanged = nil
    }

    private func environmentUserID(_ accountID: String) -> String {
        serverEnvironment == .sandbox ? "jizhi_sandbox_" + accountID.lowercased() : Self.appUserID(accountID)
    }

    func price(for plan: MembershipPlan) -> String? {
        offers.first { $0.plan == plan }?.localizedPrice
    }

    func isAvailable(_ plan: MembershipPlan) -> Bool {
        isConfigured && desiredUserID != nil && !isLoading && !isPurchasing && offers.contains { $0.plan == plan }
    }

    func refreshCustomerInfo() async throws { try await enqueue(.refresh) }
    func refreshAfterRedemption() async throws { try await enqueue(.sync) }

    static func appUserID(_ accountID: String) -> String { "jizhi_" + accountID.lowercased() }

    func purchase(plan: MembershipPlan) async throws {
        guard !isPurchasing else { throw PaymentError.busy }
        guard desiredUserID != nil else { throw PaymentError.signInRequired }
        guard let offer = offers.first(where: { $0.plan == plan }) else { throw PaymentError.unavailable }
        isPurchasing = true
        defer { isPurchasing = false }
        try await enqueue(.purchase(offer.packageID))
    }

    func purchaseDefaultPackage() async throws { try await purchase(plan: .pro) }

    func restorePurchases() async throws {
        guard !isPurchasing else { throw PaymentError.busy }
        guard desiredUserID != nil else { throw PaymentError.signInRequired }
        isPurchasing = true
        defer { isPurchasing = false }
        try await enqueue(.restore)
    }

    private enum Operation { case refresh, purchase(String), restore, sync }

    private func enqueue(_ operation: Operation) async throws {
        guard isConfigured else { throw AppError.paymentNotConfigured }
        let epoch = generation
        let user = desiredUserID
        let previous = tail
        pendingOperations += 1
        isLoading = true
        let task = Task { @MainActor in
            _ = await previous?.result
            try self.check(epoch, user: user)
            try await self.adapter.identify(userID: user.map(self.environmentUserID))
            try self.check(epoch, user: user)
            guard self.adapter.userID == user.map(self.environmentUserID) else { throw PaymentError.accountChanged }
            guard user != nil else { return }
            let info: EntitlementState
            switch operation {
            case .refresh:
                info = try await self.adapter.customerInfo()
                try self.check(epoch, user: user)
                self.entitlementState = info
            case .purchase(let package): info = try await self.adapter.purchase(packageID: package)
            case .restore: info = try await self.adapter.restore()
            case .sync: info = try await self.adapter.syncPurchases()
            }
            try self.check(epoch, user: user)
            self.entitlementState = info
            self.lastError = nil
            if let user, let reconcile = self.reconcileMembership {
                do {
                    let serverPlan = try await reconcile(user)
                    try self.check(epoch, user: user)
                    self.serverMembershipPlan = serverPlan
                    self.serverSyncPending = serverPlan != info.membershipPlan
                } catch {
                    try self.check(epoch, user: user)
                    // The store result remains valid even when backend quota synchronization fails.
                    self.serverSyncPending = true
                }
            }
            if case .refresh = operation {
                let offers = try await self.adapter.offerings()
                try self.check(epoch, user: user)
                guard !offers.isEmpty else { throw PaymentError.catalogUnavailable }
                self.offers = offers
            }
        }
        tail = task
        defer { pendingOperations -= 1; isLoading = pendingOperations > 0 }
        do { try await task.value }
        catch {
            let safeError = RevenueCatSDKAdapter.normalized(error)
            if generation == epoch, safeError != .cancelled { lastError = AppError(safeError) }
            throw safeError
        }
    }

    private func check(_ epoch: UUID, user: String?) throws {
        guard epoch == generation, desiredUserID == user else { throw PaymentError.accountChanged }
    }
}
