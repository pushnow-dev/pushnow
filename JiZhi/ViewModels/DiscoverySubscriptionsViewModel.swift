import Foundation
import Observation

@MainActor @Observable
final class DiscoverySubscriptionsViewModel {
    let scope: DiscoveryAccountScope
    let channels = StaticDiscoveryCatalog.channels
    private(set) var subscriptions: [DiscoverySubscription] = []
    private(set) var loaded = false
    private(set) var errorKey: String?
    @ObservationIgnored private let auth: AuthService
    @ObservationIgnored private let store: any DiscoverySubscriptionStoring

    init(auth: AuthService, scope: DiscoveryAccountScope, store: (any DiscoverySubscriptionStoring)? = nil) {
        self.auth = auth
        self.scope = scope
        self.store = store ?? DiscoverySubscriptionStore()
    }

    var isCurrentAccount: Bool {
        DiscoveryAccountScope(session: auth.session, generation: auth.generation) == scope
    }

    func subscription(for channelID: String) -> DiscoverySubscription? {
        guard isCurrentAccount else { return nil }
        return subscriptions.first { $0.channelID == channelID }
    }

    func load() {
        subscriptions = []; loaded = false; errorKey = nil
        do {
            try requireAccount()
            subscriptions = try store.load(accountID: scope.userID)
            loaded = true
        } catch { report(error) }
    }

    @discardableResult
    func save(_ subscription: DiscoverySubscription) -> Bool {
        mutate { values in
            guard subscription.isValid, channels.contains(where: { $0.id == subscription.channelID }) else {
                throw DiscoverySubscriptionError.invalidPreference
            }
            values.removeAll { $0.channelID == subscription.channelID }
            values.append(subscription)
        }
    }

    @discardableResult
    func unsubscribe(channelID: String) -> Bool {
        mutate { $0.removeAll { $0.channelID == channelID } }
    }

    private func mutate(_ edit: (inout [DiscoverySubscription]) throws -> Void) -> Bool {
        do {
            try requireAccount()
            guard loaded else { throw DiscoverySubscriptionError.unreadableStorage }
            // Reload before writing so another window's saved channels are preserved.
            var latest = try store.load(accountID: scope.userID)
            try edit(&latest)
            try store.save(latest, accountID: scope.userID)
            subscriptions = latest; errorKey = nil
            return true
        } catch { report(error); return false }
    }

    private func requireAccount() throws {
        guard isCurrentAccount else { throw DiscoverySubscriptionError.accountChanged }
    }

    private func report(_ error: Error) {
        if !isCurrentAccount {
            subscriptions = []; loaded = false
            errorKey = "Your account changed. Reopen this channel."
        } else if case DiscoverySubscriptionError.invalidPreference = error {
            errorKey = "Choose a valid time and timezone."
        } else {
            errorKey = "Local preferences could not be loaded or saved. Try again."
        }
    }
}
