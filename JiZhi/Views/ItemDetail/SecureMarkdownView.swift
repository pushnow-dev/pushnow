import SwiftUI

struct SecureMarkdownView: View {
    let document: SecureMarkdownDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                SecureMarkdownContentView(document: document)
                    .padding(20)
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .environment(\.openURL, OpenURLAction { url in
                ["https", "http"].contains(url.scheme?.lowercased() ?? "") ? .systemAction : .discarded
            })
        }
    }
}

struct SecureMarkdownContentView: View {
    let document: SecureMarkdownDocument

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(document.blocks) { block in
                HStack(alignment: .top, spacing: 8) {
                    if let prefix = block.prefix { Text(prefix) }
                    Text(block.text)
                        .font(font(for: block))
                        .foregroundStyle(block.quote ? .secondary : .primary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func font(for block: SecureMarkdownBlock) -> Font {
        if block.code { return .body.monospaced() }
        if let heading = block.heading { return heading == 1 ? .title2.bold() : .headline }
        return .body
    }
}
