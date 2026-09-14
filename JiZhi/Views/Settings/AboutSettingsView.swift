import SwiftUI

struct AboutSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        List {
            LabeledContent("名称", value: environment.configuration.appName)
            LabeledContent("版本", value: "\(environment.systemService.appVersion) (\(environment.systemService.buildNumber))")
            LabeledContent("最低系统", value: environment.configuration.minimumOSVersion)
        }
        .navigationTitle(Text(verbatim: AppLocalization.text("About", language: environment.preferences.language)))
        .scrollContentBackground(.hidden)
        .background(JZColor.background)
    }
}
