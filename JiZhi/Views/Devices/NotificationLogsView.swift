import SwiftUI

struct NotificationLogsView: View {
    let device: SecureDeviceService
    var keyId: String? = nil
    @State private var model = SenderManagementService()

    var body: some View {
        List {
            if model.loaded && model.logs.isEmpty {
                ContentUnavailableView("No notification logs", systemImage: "tray")
            }
            ForEach(model.logs) { log in
                NavigationLink {
                    NotificationLogDetail(log: log, device: device).localizedNavigationBack()
                } label: { NotificationLogRow(log: log) }
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red)
                Button("Retry") {
                    Task { await model.loadLogs(device: device, keyId: keyId, more: model.retryMore) }
                }.disabled(model.busy)
            }
            if model.busy { ProgressView() }
            if model.nextCursor != nil {
                Button("Load more") { Task { await model.loadLogs(device: device, keyId: keyId, more: true) } }
                    .disabled(model.busy)
            }
        }
        .navigationTitle("Notification logs")
        .task(id: keyId) { model.clear(); await model.loadLogs(device: device, keyId: keyId) }
        .refreshable { await model.loadLogs(device: device, keyId: keyId) }
        .onChange(of: device.auth.generation) { model.clear() }
    }
}

private struct NotificationLogRow: View {
    @Environment(AppEnvironment.self) private var environment
    let log: SenderNotificationLog
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(log.sourceName ?? log.sourceId).font(.headline)
            Text(log.messageId).font(.caption.monospaced()).lineLimit(1)
            if let date = SecureCrypto.date(log.createdAt) {
                Text(date, format: Date.FormatStyle(date: .abbreviated, time: .shortened,
                    locale: environment.preferences.locale, timeZone: AppTimestamp.zone(environment.preferences.timezoneIdentifier)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if log.deliveries.isEmpty { Text("No device deliveries").font(.caption).foregroundStyle(.secondary) }
            else { Text("Devices: \(log.deliveries.count)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct NotificationLogDetail: View {
    let log: SenderNotificationLog
    let device: SecureDeviceService
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section("Notification") {
                LabeledContent("Source", value: log.sourceName ?? log.sourceId)
                LabeledContent("Message ID", value: log.messageId).textSelection(.enabled)
                if let keyId = log.keyId { LabeledContent("Key ID", value: keyId).textSelection(.enabled) }
                SenderTimestampRow(title: "Created", value: log.createdAt)
                SenderTimestampRow(title: "Scheduled", value: log.scheduledAt, fallback: "Immediately")
                SenderTimestampRow(title: "Expires", value: log.expiresAt, fallback: "Never")
                SenderTimestampRow(title: "Read", value: log.readAt, fallback: "Unread")
            }
            Section("Device deliveries") {
                if log.deliveries.isEmpty { Text("No device deliveries").foregroundStyle(.secondary) }
                ForEach(log.deliveries) { delivery in NotificationDeliveryRow(delivery: delivery) }
            }
        }
        .navigationTitle("Notification details")
        .onChange(of: device.auth.generation) { dismiss() }
    }
}

private struct NotificationDeliveryRow: View {
    @Environment(AppEnvironment.self) private var environment
    let delivery: SenderDeliveryLog
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(delivery.deviceName ?? delivery.deviceId).font(.headline)
            Text(delivery.deviceId).font(.caption.monospaced()).textSelection(.enabled)
            LabeledContent("Status") { Text(LocalizedStringKey(statusLabel)) }
            LabeledContent("Attempts", value: delivery.attempts.formatted(.number.locale(environment.preferences.locale)))
            SenderTimestampRow(title: "Accepted by push service", value: delivery.acceptedAt)
            if delivery.lastError != nil {
                Text("Notification delivery failed. Check the device or contact support.")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var statusLabel: String {
        switch delivery.status {
        case "pending", "queued": "Pending"
        case "accepted": "Accepted by push service"
        case "retry": "Retrying"
        case "blocked": "Blocked"
        case "failed": "Failed"
        case "suppressed": "Suppressed"
        case "sent": "Sent"
        case "expired": "Expired"
        default: "Unknown delivery status"
        }
    }
}
