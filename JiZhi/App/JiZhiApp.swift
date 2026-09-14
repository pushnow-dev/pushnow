import SwiftUI

@main
struct JiZhiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .id(environment.identity)
                .environment(environment)
                .environment(\.locale, environment.preferences.locale)
                .onReceive(NotificationCenter.default.publisher(for: .serverEnvironmentChanged)) { _ in
                    environment = AppEnvironment.live()
                }
                .preferredColorScheme(environment.preferences.appearance.colorScheme)
        }
    }
}
