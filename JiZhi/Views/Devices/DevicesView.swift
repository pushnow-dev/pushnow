import SwiftUI

struct DevicesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var service: SecureDeviceService?
    var body: some View {
        Group {
            if let service { DeviceListView(service: service) } else { ProgressView() }
        }
        .navigationTitle("Devices & Encryption")
        .task {
            if service == nil {
                service = environment.authService.secureDevices(api: APIClient(baseURL: environment.configuration.apiBaseURL))
            }
            await service?.refresh()
        }
    }
}

private struct DeviceListView: View {
    @Bindable var service: SecureDeviceService
    var body: some View {
        List {
            if let error = service.error { Text(error).foregroundStyle(.red) }
            Section("This device") {
                if service.trusted, let root = service.keys?.identityPublicKey {
                    LabeledContent("Account fingerprint") {
                        Text(SecureCrypto.fingerprint(root)).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if !service.trusted {
                    LabeledContent("Pairing code") {
                        Text(service.pairingCode).font(.callout.monospaced()).textSelection(.enabled)
                            .accessibilityIdentifier("pairing-code-value")
                    }
                    Label("Waiting for device approval", systemImage: "lock.shield")
                }
            }
            Section("Account devices") {
                ForEach(service.devices.filter { $0.status != "revoked" }) { device in
                    DeviceRow(device: device, service: service)
                }
            }
            if service.trusted {
                NavigationLink("Senders") { SenderAuthorizationView(device: service).localizedNavigationBack() }
                Button("Sync encrypted history key") {
                    Task {
                        do { _ = try await SecureArchiveService.ensure(service: service) }
                        catch { service.error = AppError(error).localizedDescription }
                    }
                }
            }
        }
        .refreshable { await service.refresh() }
        .task {
            while !Task.isCancelled {
                if !service.trusted { await service.refresh() }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
    }
}
