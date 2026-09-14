import SwiftUI

struct SenderKeysView: View {
    let device: SecureDeviceService
    @State private var model = SenderManagementService()
    @State private var editor: KeyEditorTarget?
    @State private var revokeTarget: SenderKey?

    var body: some View {
        List {
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.loadKeys(device: device) } }
                }
            }
            if model.busy { ProgressView() }
            if model.loaded && model.keys.isEmpty {
                ContentUnavailableView("No sender keys", systemImage: "key")
            }
            ForEach(model.keys) { key in
                Section {
                    SenderKeySummary(key: key)
                    NavigationLink {
                        NotificationLogsView(device: device, keyId: key.id).localizedNavigationBack()
                    } label: { Label("Notification logs", systemImage: "list.bullet.rectangle") }
                    if key.revokedAt == nil {
                        Button("Edit expiry", systemImage: "calendar") { editor = .init(key: key, creating: false) }
                        Button("Create another key", systemImage: "key.fill") { editor = .init(key: key, creating: true) }
                        Button("Revoke key", systemImage: "trash", role: .destructive) { revokeTarget = key }
                    }
                }.disabled(model.busy)
            }
        }
        .navigationTitle("Sender keys")
        .task { await model.loadKeys(device: device) }
        .refreshable { await model.loadKeys(device: device) }
        .onChange(of: device.auth.generation) {
            editor = nil; revokeTarget = nil; model.clear()
        }
        .sheet(item: $editor, onDismiss: { model.secret = nil }) { target in
            SenderKeyEditor(target: target, device: device, model: model)
        }
        .confirmationDialog("Revoke key?", isPresented: Binding(
            get: { revokeTarget != nil }, set: { if !$0 { revokeTarget = nil } }
        ), titleVisibility: .visible) {
            if let key = revokeTarget {
                Button("Revoke key", role: .destructive) {
                    Task { await model.revoke(key, device: device); revokeTarget = nil }
                }
            }
        } message: { Text("This key will no longer be able to send notifications.") }
    }
}

private struct KeyEditorTarget: Identifiable {
    let id = UUID()
    let key: SenderKey
    let creating: Bool
}

private struct SenderKeySummary: View {
    let key: SenderKey
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(key.sourceName ?? key.sourceId).font(.headline)
            Text(key.keyPrefix).font(.caption.monospaced()).textSelection(.enabled)
            LabeledContent("Status") { Text(LocalizedStringKey(key.state)) }
            SenderTimestampRow(title: "Created", value: key.createdAt)
            SenderTimestampRow(title: "Expires", value: key.expiresAt, fallback: "Never")
            SenderTimestampRow(title: "Last used", value: key.lastUsedAt, fallback: "Not used yet")
            if let revoked = key.revokedAt { SenderTimestampRow(title: "Revoked", value: revoked) }
        }
    }
}

private struct SenderKeyEditor: View {
    let target: KeyEditorTarget
    let device: SecureDeviceService
    @Bindable var model: SenderManagementService
    @Environment(\.dismiss) private var dismiss
    @State private var expiry = SenderKeyExpiry.never

    var body: some View {
        NavigationStack {
            Form {
                if let secret = model.secret {
                    Section("New sender key") {
                        Text(secret.value).font(.body.monospaced()).textSelection(.enabled).privacySensitive()
                        Text("Keep this key safe. It will only be shown once.").foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text(target.key.sourceName ?? target.key.sourceId)
                        if !target.creating {
                            SenderTimestampRow(title: "Current expiry", value: target.key.expiresAt, fallback: "Never")
                        }
                        SenderExpiryPicker(selection: $expiry)
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                    Button(LocalizedStringKey(target.creating ? "Create key" : "Save")) { Task { await save() } }
                        .disabled(model.busy)
                    if model.busy { ProgressView() }
                }
            }
            .navigationTitle(Text(LocalizedStringKey(target.creating ? "Create key" : "Edit expiry")))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.secret = nil; dismiss() }.disabled(model.busy)
                }
            }
            .interactiveDismissDisabled(model.busy)
        }
    }

    private func save() async {
        if target.creating {
            _ = await model.create(sourceId: target.key.sourceId, expiry: expiry, device: device)
        } else if await model.update(target.key, expiry: expiry, device: device) { dismiss() }
    }
}

struct SenderExpiryPicker: View {
    @Binding var selection: SenderKeyExpiry
    var body: some View {
        Picker("Key expiry", selection: $selection) {
            ForEach(SenderKeyExpiry.allCases) { preset in
                Text(LocalizedStringKey(preset.title)).tag(preset)
            }
        }
    }
}

struct SenderTimestampRow: View {
    @Environment(AppEnvironment.self) private var environment
    let title: LocalizedStringKey
    let value: String?
    var fallback: LocalizedStringKey = "Not available"
    var body: some View {
        LabeledContent {
            if let value, let date = SecureCrypto.date(value) {
                Text(date, format: Date.FormatStyle(date: .abbreviated, time: .shortened,
                    locale: environment.preferences.locale, timeZone: AppTimestamp.zone(environment.preferences.timezoneIdentifier)))
                    .multilineTextAlignment(.trailing)
            } else { Text(fallback) }
        } label: { Text(title) }
    }
}
