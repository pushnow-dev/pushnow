import SwiftUI

struct TimezoneSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var search = ""
    private var zones: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted().filter {
            search.isEmpty || zoneTitle($0).range(of: search, options: [.caseInsensitive, .diacriticInsensitive],
                locale: environment.preferences.locale) != nil
        }
    }

    var body: some View {
        List {
            Section {
                selection("system", title: AppLocalization.text("Follow system", language: environment.preferences.language))
            }
            Section {
                ForEach(zones, id: \.self) { identifier in
                    selection(identifier, title: zoneTitle(identifier))
                }
            }
        }
        .navigationTitle("Time zone")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search time zones")
        .scrollContentBackground(.hidden)
        .background(JZColor.background)
    }

    private func zoneTitle(_ identifier: String) -> String {
        guard let name = TimeZone(identifier: identifier)?.localizedName(for: .generic,
            locale: environment.preferences.locale) else { return identifier }
        return "\(name) · \(identifier)"
    }

    private func selection(_ identifier: String, title: String) -> some View {
        Button {
            environment.preferences.timezoneIdentifier = identifier
        } label: {
            HStack {
                Text(verbatim: title).foregroundStyle(JZColor.text)
                Spacer()
                if environment.preferences.timezoneIdentifier == identifier {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(environment.preferences.timezoneIdentifier == identifier ? .isSelected : [])
    }
}
