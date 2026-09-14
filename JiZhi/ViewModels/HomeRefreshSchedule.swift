import Foundation

/// One immediate refresh, then a delay after each completed refresh; no overlap.
@MainActor
enum HomeRefreshSchedule {
    static let interval: Duration = .seconds(30)

    static func isEnabled(isForeground: Bool, isHome: Bool, isRoot: Bool,
                          hasSheet: Bool, isVerified: Bool) -> Bool {
        isForeground && isHome && isRoot && !hasSheet && isVerified
    }

    static func run(refresh: () async -> Void,
                    sleep: () async throws -> Void = { try await Task.sleep(for: interval) }) async {
        while !Task.isCancelled {
            await refresh()
            guard !Task.isCancelled else { return }
            do { try await sleep() } catch { return }
        }
    }
}
