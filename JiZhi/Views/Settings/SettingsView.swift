import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        List {
            Section {
                NavigationLink { AccountSettingsView().localizedNavigationBack() } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
                NavigationLink { MembershipSettingsView().localizedNavigationBack() } label: {
                    Label("Membership", systemImage: "crown")
                }
            }
            Section("Preferences") {
                NavigationLink { TimezoneSettingsView().localizedNavigationBack() } label: {
                    LabeledContent {
                        if environment.preferences.timezoneIdentifier == "system" {
                            Text("Follow system").foregroundStyle(.secondary)
                        } else {
                            Text(verbatim: TimeZone(identifier: environment.preferences.timezoneIdentifier)?
                                .localizedName(for: .generic, locale: environment.preferences.locale)
                                ?? environment.preferences.timezoneIdentifier).foregroundStyle(.secondary)
                        }
                    } label: { Label("Time zone", systemImage: "clock") }
                }
                NavigationLink { LanguageSettingsView().localizedNavigationBack() } label: {
                    LabeledContent {
                        Text(verbatim: environment.preferences.language.nativeName).foregroundStyle(.secondary)
                    } label: { Label("Language", systemImage: "globe") }
                }
                NavigationLink { AppearanceSettingsView().localizedNavigationBack() } label: {
                    LabeledContent {
                        Text(environment.preferences.appearance.title).foregroundStyle(.secondary)
                    } label: { Label("Appearance", systemImage: "circle.lefthalf.filled") }
                }
            }
            Section("应用") {
                NavigationLink { AboutSettingsView().localizedNavigationBack() } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
            Section("法律") {
                if let url = environment.configuration.privacyPolicyURL { Link("隐私政策", destination: url) }
                if let url = environment.configuration.termsOfUseURL { Link("使用条款", destination: url) }
            }
        }
        .navigationTitle(Text(verbatim: AppLocalization.text("设置", language: environment.preferences.language)))
        .scrollContentBackground(.hidden)
        .background(JZColor.background)
    }
}
