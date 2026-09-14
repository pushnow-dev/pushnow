import SwiftUI

struct AppRootView: View {
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            TabView(selection: $router.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    tab.rootView
                        .tabItem { tab.label }
                        .tag(tab)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                route.destinationView
            }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheet.destinationView
        }
        .environment(router)
    }
}

#Preview {
    AppRootView()
        .environment(AppEnvironment.preview())
}
