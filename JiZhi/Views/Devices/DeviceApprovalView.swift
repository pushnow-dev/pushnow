import SwiftUI

struct DeviceApprovalView: View {
    let device: SecureDevice
    let service: SecureDeviceService
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var error: String?
    var body: some View {
        Form {
            LabeledContent("Device name", value: device.name)
            TextField("Pairing code", text: $code)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .accessibilityIdentifier("device-pairing-code")
            if let error { Text(error).foregroundStyle(.red) }
            Button("Approve device") {
                Task {
                    do { try await service.approvePairing(device, code: code); dismiss() }
                    catch { self.error = AppError(error).localizedDescription }
                }
            }
            .disabled(code.filter { $0.isHexDigit }.count != 16)
        }
        .navigationTitle("Approve device")
    }
}
