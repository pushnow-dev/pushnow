import SwiftUI

struct DeliveryToggleRow: View {
    @Environment(\.locale) private var locale
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 28)
            Text(verbatim: AppLocalization.text(title, locale: locale))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Toggle(AppLocalization.text(title, locale: locale), isOn: $isOn)
                .labelsHidden()
                .tint(JZColor.blue)
        }
        .foregroundStyle(JZColor.text)
        .padding(.vertical, 12)
    }
}

extension JiZhiPriority {
    var apiValue: String {
        switch self {
        case .normal: "normal"
        case .important: "important"
        case .urgent: "P0"
        case .custom: "P1"
        }
    }
}

extension Date {
    var jzDelayLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocalization.locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var jzISOString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
