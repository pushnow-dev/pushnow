import SwiftUI

struct MessageSourceBadge: View {
    @Environment(\.locale) private var locale
    var kind: String?
    var sourceType: String? = nil
    var name: String? = nil
    var compact = false

    private var category: MessageSourceCategory? {
        MessageSourceCategory(kind: kind, sourceType: sourceType)
    }

    private var title: String {
        guard let category else {
            if let name, !name.isEmpty { return name }
            return AppLocalization.text("Message source", locale: locale)
        }
        let label = category.localizedTitle(locale: locale)
        guard !compact, let name, !name.isEmpty else { return label }
        return "\(label) · \(name)"
    }

    private var icon: String {
        category?.iconName ?? "link"
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundStyle(JZColor.muted)
            .lineLimit(compact ? 1 : 2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(JZColor.grouped, in: Capsule())
    }
}
