import SwiftUI

struct ReminderEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var selectedMode = "延迟"
    @State private var pushEnabled: Bool
    @State private var requiresAck: Bool
    @State private var selectedPriority: JiZhiPriority
    @State private var scheduledDate = Date().addingTimeInterval(5 * 60 * 60)
    @State private var isSaving = false
    @State private var errorMessage: String?

    let item: InboxItem
    private let modes = ["仅保存", "立即", "延迟", "指定时间", "循环"]

    init(item: InboxItem) {
        self.item = item
        _pushEnabled = State(initialValue: item.pushEnabled)
        _requiresAck = State(initialValue: item.requiresAck)
        _selectedPriority = State(initialValue: item.priority)
    }

    var body: some View {
        VStack(spacing: 0) {
            CompactNavBar(title: "安排提醒", showsBack: true, onBack: router.pop)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    modeChips
                    delayPicker
                    datePicker
                    prioritySection
                    deliverySection
                    errorText
                    Spacer(minLength: 12)
                    saveButton
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .background(JZColor.background)
        .onChange(of: pushEnabled) {
            if !pushEnabled {
                requiresAck = false
            }
        }
    }

    private var modeChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(modes, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                        if mode == "仅保存" {
                            pushEnabled = false
                            requiresAck = false
                        }
                    } label: {
                        FilterChip(title: mode, isSelected: selectedMode == mode)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var delayPicker: some View {
        VStack(spacing: 8) {
            Text(verbatim: selectedMode == "立即" ? AppLocalization.text("立即提醒", locale: environment.preferences.locale) : selectedMode == "仅保存" ? AppLocalization.text("仅 App 内查看", locale: environment.preferences.locale) : scheduledDate.jzDelayLabel)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(JZColor.blue)
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(JZColor.grouped, in: .rect(cornerRadius: 10))

            Text(verbatim: AppTimestamp.zone(environment.preferences.timezoneIdentifier).identifier)
                .font(.caption)
                .foregroundStyle(JZColor.muted)
        }
    }

    @ViewBuilder
    private var datePicker: some View {
        if selectedMode == "延迟" || selectedMode == "指定时间" || selectedMode == "循环" {
            DatePicker("提醒时间", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .environment(\.timeZone, AppTimestamp.zone(environment.preferences.timezoneIdentifier))
                .jzCardStyle()
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("紧急程度")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JZColor.text)

            HStack {
                ForEach(JiZhiPriority.allCases) { priority in
                    Button {
                        selectedPriority = priority
                    } label: {
                        StatusBadge(
                            title: AppLocalization.text(priority.rawValue, locale: environment.preferences.locale),
                            tint: selectedPriority == priority ? .white : priority.tint,
                            background: selectedPriority == priority ? priority.tint : priority.background
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    private var deliverySection: some View {
        VStack(spacing: 0) {
            DeliveryToggleRow(icon: "bell", title: "App 推送", isOn: $pushEnabled)
            Divider().padding(.leading, 46)
            inAppOnlyRow
            Divider().padding(.leading, 46)
            DeliveryToggleRow(icon: "checkmark.circle", title: "需要确认收到", isOn: $requiresAck)
                .disabled(!pushEnabled)
                .opacity(pushEnabled ? 1 : 0.45)
        }
        .jzCardStyle()
    }

    private var inAppOnlyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(.headline)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("不通知时仅 App 内查看")
                    .font(.subheadline.weight(.semibold))
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
            }
            Spacer()
        }
        .foregroundStyle(JZColor.text)
        .padding(.vertical, 12)
    }

    private var saveButton: some View {
        Button(AppLocalization.text(isSaving ? "正在保存" : "保存提醒", locale: environment.preferences.locale)) {
            Task {
                await saveReminder()
            }
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(JZColor.primary, in: .rect(cornerRadius: 14))
        .disabled(isSaving)
    }

    @ViewBuilder
    private var errorText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(JZColor.red)
        }
    }

    private func saveReminder() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await environment.repository.createReminder(for: item.id, input: reminderInput)
            router.pop()
        } catch {
            errorMessage = AppError(error).localizedDescription
        }
    }

    private var reminderInput: ReminderCreationInput {
        let mode = apiMode
        return ReminderCreationInput(
            mode: mode,
            scheduledAt: mode == "now" || mode == "in_app_only" ? nil : scheduledDate.jzISOString,
            timezone: AppTimestamp.zone(environment.preferences.timezoneIdentifier).identifier,
            repeatRule: selectedMode == "循环" ? "FREQ=DAILY" : nil,
            priority: selectedPriority.apiValue,
            pushEnabled: pushEnabled,
            requiresAck: pushEnabled && requiresAck
        )
    }

    private var apiMode: String {
        switch selectedMode {
        case "仅保存": "in_app_only"
        case "立即": "now"
        case "延迟": "delay"
        default: "scheduled"
        }
    }
}

#Preview {
    ReminderEditorView(item: .init(id: "q2", source: "Research Agent", category: "AI 趋势报告", title: "Q2 竞品分析已完成", summary: "包含报告、表格和 3 个附件", time: "15:12", icon: "doc.text", unread: true, priority: .important, reminderBadge: "5 小时后", requiresAck: true, pushEnabled: true))
        .environment(AppEnvironment.preview())
        .environment(AppRouter())
}
