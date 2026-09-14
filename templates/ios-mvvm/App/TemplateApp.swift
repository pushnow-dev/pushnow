import SwiftUI

@main
struct TemplateApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(environment)
        }
    }
}
