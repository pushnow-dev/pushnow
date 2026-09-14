import SwiftUI

struct AppRootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase
    @State private var accountSender = SenderAuthorizationService()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            AppShellView(selectedTab: $router.selectedTab)
                .navigationDestination(for: AppRoute.self) { route in
                    route.destinationView
                }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheet.destinationView
        }
        .task {
            await environment.pushRegistrationService.refreshAuthorizationStatus()
            await environment.pushRegistrationService.bindStoredTokenIfPossible()
            await openNotification()
        }
        .task(id: "\(scenePhase)-\(environment.authService.generation)") {
            guard scenePhase == .active, environment.authService.isVerified else { return }
            await accountSender.monitorAccountRequests(environment: environment)
        }
        .onChange(of: environment.authService.isVerified) { _, isVerified in
            guard isVerified else { return }
            Task {
                await environment.pushRegistrationService.enableAfterVerifiedLoginIfPossible()
                await openNotification()
            }
        }
        .environment(router)
        .onReceive(NotificationCenter.default.publisher(for: .openSecureMessage)) { _ in
            Task { await openNotification() }
        }
    }

    private func openNotification() async {
        guard let pending = SecureNotificationRoute.pending,
              pending.user == environment.authService.session?.userID else { return }
        SecureNotificationRoute.pending = nil
        do {
            let result = try await SecureV2Inbox.message(id: pending.id,
                api: APIClient(baseURL: environment.configuration.apiBaseURL), auth: environment.authService)
            router.push(.itemDetail(SecureV2Inbox.item(result.0, content: result.1)))
        } catch { /* Invalid or deleted notifications never route to unverified content. */ }
    }
}

private struct AppShellView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            selectedTab.rootView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            JiZhiTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .fixedSize(horizontal: false, vertical: true)
                .background(JZColor.background.ignoresSafeArea(edges: .bottom))
        }
        .background(JZColor.background.ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

#Preview {
    AppRootView()
        .environment(AppEnvironment.preview())
}
