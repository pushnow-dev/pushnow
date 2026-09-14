import SwiftUI

enum AppRoute: Hashable {
    case itemDetail(InboxItem)
    case reminderEditor(InboxItem)
    case auth
    case settings

    @MainActor
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .itemDetail(let item):
            if item.id.hasPrefix("v2:") || item.id.hasPrefix("secure:") {
                ItemDetailView(item: item).localizedNavigationBack()
            } else {
                ItemDetailView(item: item).navigationBarBackButtonHidden(true)
            }
        case .reminderEditor(let item):
            ReminderEditorView(item: item).navigationBarBackButtonHidden(true)
        case .auth:
            AuthView().navigationBarBackButtonHidden(true)
        case .settings:
            SettingsView().localizedNavigationBack()
        }
    }
}
