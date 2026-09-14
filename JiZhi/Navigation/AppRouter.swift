import Observation

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .inbox
    var path: [AppRoute] = []
    var presentedSheet: SheetDestination?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func present(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
