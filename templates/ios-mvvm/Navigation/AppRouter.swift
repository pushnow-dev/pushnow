import Observation

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []
    var presentedSheet: SheetDestination?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func present(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
