import SwiftUI

struct SecureSourceEntryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var service: SecureDeviceService?
    var body: some View {
        Group {
            if let service {
                if service.trusted { SenderAuthorizationView(device: service) }
                else { DevicesView() }
            } else { ProgressView() }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
        }
        .task {
            let value = environment.authService.secureDevices(api: APIClient(baseURL: environment.configuration.apiBaseURL))
            await value.refresh()
            service = value
        }
    }
}
