import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    var body: some View {
        @Bindable var preferences = environment.preferences
        List {
            Picker("Appearance", selection: $preferences.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label { Text(appearance.title) } icon: { Image(systemName: appearance.icon) }.tag(appearance)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle(Text(verbatim: AppLocalization.text("Appearance", language: environment.preferences.language)))
        .scrollContentBackground(.hidden)
        .background(JZColor.background)
    }
}
