import SwiftUI

struct LoadingStateView: View {
    @Environment(\.locale) private var locale
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(verbatim: AppLocalization.text(title, locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
