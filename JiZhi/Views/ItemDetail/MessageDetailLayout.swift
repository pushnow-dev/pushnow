import SwiftUI

struct MessageDetailHeader: View {
    let title: String
    let timeText: String
    var sourceKind: String?
    var sourceType: String?
    var sourceName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(.title2.bold())
                .foregroundStyle(JZColor.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 8) {
                Text(verbatim: timeText)
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
                    .lineLimit(1)
                    .textSelection(.enabled)

                Spacer(minLength: 8)

                MessageSourceBadge(kind: sourceKind, sourceType: sourceType, name: sourceName, compact: true)
            }
        }
    }
}

struct MessageDetailBodyText: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.body)
            .lineSpacing(5)
            .multilineTextAlignment(.center)
            .foregroundStyle(JZColor.text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            .padding(.vertical, 12)
    }
}
