import Foundation

@MainActor
protocol DiscoverySubscriptionStoring {
    func load(accountID: String) throws -> [DiscoverySubscription]
    func save(_ subscriptions: [DiscoverySubscription], accountID: String) throws
}

@MainActor
final class DiscoverySubscriptionStore: DiscoverySubscriptionStoring {
    private let defaults: UserDefaults
    private let environment: ServerEnvironment
    init(defaults: UserDefaults = .standard, environment: ServerEnvironment = .current) {
        self.defaults = defaults
        self.environment = environment
    }

    func load(accountID: String) throws -> [DiscoverySubscription] {
        guard !accountID.isEmpty else { throw DiscoverySubscriptionError.accountChanged }
        guard defaults.object(forKey: storageKey(accountID)) != nil else { return [] }
        guard let data = defaults.data(forKey: storageKey(accountID)) else {
            throw DiscoverySubscriptionError.unreadableStorage
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == 1, envelope.accountID == accountID,
              envelope.subscriptions.allSatisfy(\.isValid),
              Set(envelope.subscriptions.map(\.channelID)).count == envelope.subscriptions.count else {
            throw DiscoverySubscriptionError.unreadableStorage
        }
        return envelope.subscriptions
    }

    func save(_ subscriptions: [DiscoverySubscription], accountID: String) throws {
        guard !accountID.isEmpty else { throw DiscoverySubscriptionError.accountChanged }
        guard subscriptions.allSatisfy(\.isValid),
              Set(subscriptions.map(\.channelID)).count == subscriptions.count else {
            throw DiscoverySubscriptionError.invalidPreference
        }
        let envelope = Envelope(version: 1, accountID: accountID, subscriptions: subscriptions)
        defaults.set(try JSONEncoder().encode(envelope), forKey: storageKey(accountID))
    }

    func storageKey(_ accountID: String) -> String {
        environment.key("pushnow.discovery.subscriptions.v1." + Data(accountID.utf8).base64EncodedString())
    }

    private struct Envelope: Codable {
        let version: Int
        let accountID: String
        let subscriptions: [DiscoverySubscription]
    }
}
