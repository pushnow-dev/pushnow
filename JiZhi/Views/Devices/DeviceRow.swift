import SwiftUI

struct DeviceRow: View {
    let device: SecureDevice
    let service: SecureDeviceService
    @State private var name = ""
    @State private var renaming = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone")
                Text(device.name).font(.headline)
                if device.id == service.currentID { Text("Current").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button { name = device.name; renaming = true } label: {
                    Image(systemName: "pencil").frame(width: 44, height: 44)
                }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Rename device")
            }
            if device.status == "pending" {
                Text("Pending approval").foregroundStyle(.secondary)
                if service.trusted {
                    NavigationLink("Approve device") { DeviceApprovalView(device: device, service: service).localizedNavigationBack() }
                }
            } else {
                if service.trusted, device.id != service.currentID {
                    Button("Grant history access") { perform { try await SecureArchiveService.grant(to: device, service: service) } }
                        .buttonStyle(.borderless)
                }
                Toggle("Notifications", isOn: Binding(get: { device.notificationsEnabled }, set: { enabled in
                    perform { try await service.update(device, enabled: enabled) }
                }))
            }
            Text(device.id).font(.caption.monospaced()).textSelection(.enabled)
            Text([device.model, device.systemVersion, device.appVersion].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .alert("Rename device", isPresented: $renaming) {
            TextField("Device name", text: $name)
            Button("Save") { perform { try await service.update(device, name: name) } }
            Button("Cancel", role: .cancel) {}
        }
    }
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        Task { do { try await action() } catch { service.error = AppError(error).localizedDescription } }
    }
}
