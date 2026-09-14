import SwiftUI

private struct HomeRefreshIdentity: Equatable {
    let enabled: Bool
    let account: UUID
    let language: AppLanguage
}

struct HomeRefreshModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    let model: InboxViewModel

    private var enabled: Bool {
        HomeRefreshSchedule.isEnabled(isForeground: scenePhase == .active,
            isHome: router.selectedTab == .inbox, isRoot: router.path.isEmpty,
            hasSheet: router.presentedSheet != nil, isVerified: environment.authService.isVerified)
    }

    func body(content: Content) -> some View {
        content
            .task(id: HomeRefreshIdentity(enabled: enabled, account: environment.authService.generation,
                                          language: environment.preferences.language)) {
                model.bindAccount(environment.authService.generation)
                guard enabled else { return }
                await HomeRefreshSchedule.run {
                    await model.load(repository: environment.repository,
                                     accountGeneration: environment.authService.generation)
                }
            }
            .onChange(of: enabled) { _, value in
                if !value { model.cancelLoad() }
            }
            .onChange(of: environment.authService.generation) { _, generation in
                model.bindAccount(generation)
            }
            .onDisappear { model.cancelLoad() }
    }
}
