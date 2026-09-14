import SwiftUI
import UIKit

struct SecureAttachmentPreviewSection: View {
    let rendered: [SecureRenderedAttachment]
    let loadingIDs: Set<String>
    let attachments: [SecureAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rendered) { item in
                SecureAttachmentPreview(rendered: item)
            }

            ForEach(attachments.filter { $0.isInlineRenderable && loadingIDs.contains($0.id) }) { attachment in
                HStack(spacing: 10) {
                    ProgressView()
                    Text(verbatim: attachment.name)
                        .font(.footnote)
                        .foregroundStyle(JZColor.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct SecureAttachmentPreview: View {
    let rendered: SecureRenderedAttachment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(rendered.attachment.name, systemImage: rendered.attachment.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JZColor.text)

            if rendered.attachment.isImage {
                SecureAttachmentImagePreview(url: rendered.url, name: rendered.attachment.name)
            } else if rendered.attachment.isPDF {
                SecurePDFPreview(url: rendered.url)
            } else if let document = rendered.markdown {
                SecureMarkdownContentView(document: document)
                    .padding(14)
                    .background(JZColor.grouped, in: .rect(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SecureAttachmentImagePreview: View {
    let url: URL
    let name: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 360)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityLabel(name)
        .task(id: url) {
            image = await Task.detached {
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }
}

struct SecureAttachmentListSection: View {
    let attachments: [SecureAttachment]
    let urls: [String: URL]
    let busyIDs: Set<String>
    let locale: Locale
    var download: (SecureAttachment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(attachments) { attachment in
                SecureAttachmentDownloadRow(
                    attachment: attachment,
                    url: urls[attachment.id],
                    isBusy: busyIDs.contains(attachment.id),
                    locale: locale,
                    download: { download(attachment) }
                )
            }
        }
    }
}

private struct SecureAttachmentDownloadRow: View {
    let attachment: SecureAttachment
    let url: URL?
    let isBusy: Bool
    let locale: Locale
    var download: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attachment.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(JZColor.text)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: attachment.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JZColor.text)
                    .lineLimit(2)
                Text(Int64(attachment.size).formatted(ByteCountFormatStyle(style: .file, locale: locale)))
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
            }

            Spacer(minLength: 8)

            if let url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Download")
            } else {
                Button(action: download) {
                    if isBusy {
                        ProgressView()
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .frame(width: 42, height: 42)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel("Download")
            }
        }
        .padding(12)
        .background(JZColor.grouped, in: .rect(cornerRadius: 8))
    }
}
