import SwiftUI

struct LanguageSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    var body: some View {
        @Bindable var preferences = environment.preferences
        List {
            Picker("Language", selection: $preferences.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: language == .system
                         ? AppLocalization.text("Follow system", locale: preferences.language.locale)
                         : language.nativeName).tag(language)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .id(preferences.language)
        }
        .navigationTitle(Text(verbatim: AppLocalization.text("Language", language: environment.preferences.language)))
        .scrollContentBackground(.hidden)
        .background(JZColor.background)
    }
}
