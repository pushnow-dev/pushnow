import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var showsPaywall: Bool = false

    func openPaywall() {
        showsPaywall = true
    }

    func closePaywall() {
        showsPaywall = false
    }
}
