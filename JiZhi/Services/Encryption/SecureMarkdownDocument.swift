import Foundation

struct SecureMarkdownDocument: Identifiable {
    var id = UUID()
    var name: String
    var blocks: [SecureMarkdownBlock]

    init(url: URL, name: String) throws {
        self.name = name
        let source = try String(contentsOf: url, encoding: .utf8)
        let parsed = try AttributedString(markdown: source, options: .init(interpretedSyntax: .full))
        blocks = parsed.runs[\.presentationIntent].enumerated().map { index, run in
            let (intent, range) = run
            var block = SecureMarkdownBlock(id: index, text: AttributedString(parsed[range]))
            for component in intent?.components ?? [] {
                switch component.kind {
                case .header(let level): block.heading = level
                case .codeBlock: block.code = true
                case .blockQuote: block.quote = true
                case .listItem(let ordinal):
                    let ordered = intent?.components.contains(where: { $0.kind == .orderedList }) ?? false
                    block.prefix = ordered ? "\(ordinal)." : "•"
                default: break
                }
            }
            return block
        }
    }
}

struct SecureMarkdownBlock: Identifiable {
    var id: Int
    var text: AttributedString
    var heading: Int?
    var code = false
    var quote = false
    var prefix: String?
}
