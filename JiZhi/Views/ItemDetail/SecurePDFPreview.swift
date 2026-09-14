import PDFKit
import SwiftUI

struct SecurePDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}

extension SecurePDFPreview {
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PDFView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 320, height: 420)
    }
}
