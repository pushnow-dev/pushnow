import SwiftUI

struct SenderAuthorizationView: View {
    let device: SecureDeviceService
    @Environment(AppEnvironment.self) private var environment
    @State private var model = SenderAuthorizationService()
    @State private var code = ""
    @State private var confirmed = false
    @State private var revokeTarget: AuthorizedSender?
    @State private var expiry = SenderKeyExpiry.never

    var body: some View {
        Form {
            Section {
                NavigationLink("Sender keys") { SenderKeysView(device: device).localizedNavigationBack() }
                NavigationLink("Notification logs") { NotificationLogsView(device: device).localizedNavigationBack() }
            }
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if model.approved { Label("Sender authorized", systemImage: "checkmark.shield") }
            Section("Authorize sender") {
                if let identity = device.keys?.identityPublicKey {
                    LabeledContent("Account fingerprint") {
                        Text(SecureCrypto.fingerprint(identity)).font(.caption.monospaced()).textSelection(.enabled)
                            .accessibilityIdentifier("account-fingerprint")
                    }
                }
                TextField("Authorization code", text: $code)
                    .accessibilityIdentifier("sender-code")
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("Look up code") { Task { confirmed = false; await model.lookup(code: code, device: device) } }
                    .disabled(model.busy || code.isEmpty)
                if let request = model.authorization {
                    LabeledContent("Name", value: request.name)
                    Text(SecureCrypto.fingerprint(request.publicKey)).font(.caption.monospaced()).textSelection(.enabled)
                        .accessibilityIdentifier("sender-fingerprint")
                    Toggle("Fingerprint matches my sender", isOn: $confirmed)
                        .accessibilityIdentifier("sender-confirm")
                    SenderExpiryPicker(selection: $expiry)
                    Button("Authorize sender") {
                        Task {
                            await model.approve(device: device, environment: environment,
                                confirmed: confirmed, expiresAt: expiry.expiresAt)
                        }
                    }.disabled(!confirmed || model.busy).accessibilityIdentifier("sender-approve")
                }
            }
            Section("Authorized senders") {
                ForEach(model.senders.filter { $0.status != "revoked" }) { sender in
                    HStack {
                        Text(sender.name)
                        Spacer()
                        Button("Revoke", systemImage: "trash", role: .destructive) { revokeTarget = sender }
                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: AppLocalization.text("Senders", language: environment.preferences.language)))
        .task { await model.refresh(device: device) }
        .onChange(of: device.auth.generation) {
            model.authorization = nil; model.senders = []; model.approved = false; model.error = nil
            confirmed = false; code = ""; revokeTarget = nil
        }
        .confirmationDialog("Revoke sender", isPresented: Binding(get: { revokeTarget != nil }, set: { if !$0 { revokeTarget = nil } })) {
            if let sender = revokeTarget {
                Button("Revoke", role: .destructive) { Task { await model.revoke(sender, device: device); revokeTarget = nil } }
            }
        }
    }
}
