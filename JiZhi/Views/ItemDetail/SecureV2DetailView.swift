import SwiftUI
import QuickLook

struct SecureV2DetailView: View {
    let id: String
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var model = SecureV2DetailModel()
    @State private var deleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error = model.error { Text(error).foregroundStyle(.red) }
                if let content = model.content {
                    MessageDetailHeader(
                        title: content.title,
                        timeText: model.message?.createdAt.map {
                            AppTimestamp.readable($0, timezoneIdentifier: environment.preferences.timezoneIdentifier)
                        } ?? "",
                        sourceKind: model.message?.sourceKind,
                        sourceType: model.message?.sourceType,
                        sourceName: model.message?.sourceName
                    )
                    MessageDetailBodyText(text: content.body)
                    SecureAttachmentPreviewSection(
                        rendered: model.renderedAttachments,
                        loadingIDs: model.attachmentBusyIDs,
                        attachments: content.attachments
                    )
                    linkList(content.links)
                    SecureAttachmentListSection(
                        attachments: content.attachments,
                        urls: model.downloadURLs,
                        busyIDs: model.attachmentBusyIDs,
                        locale: locale
                    ) { attachment in
                        Task { await model.download(attachment, environment: environment) }
                    }
                } else if model.busy { ProgressView() }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete message", systemImage: "trash", role: .destructive) { deleting = true }
                    .disabled(model.content == nil || model.busy)
            }
        }
        .confirmationDialog("Delete message", isPresented: $deleting) {
            Button("Delete message", role: .destructive) {
                Task { if await model.delete(environment: environment) { dismiss() } }
            }
        }
        .quickLookPreview($model.previewURL)
        .sheet(item: $model.markdown) { document in SecureMarkdownView(document: document) }
        .task { await model.load(id: id, environment: environment) }
        .task(id: inlineAttachmentSignature) { await model.renderInlineAttachments(environment: environment) }
        .onDisappear { model.clearFiles() }
        .onChange(of: environment.authService.generation) { model.clearFiles(); model.content = nil; dismiss() }
    }

    private var inlineAttachmentSignature: String {
        model.content?.attachments.filter(\.isInlineRenderable).map(\.id).joined(separator: ",") ?? ""
    }

    @ViewBuilder
    private func linkList(_ links: [String]) -> some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(links, id: \.self) { value in
                    if let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                        Link(destination: url) {
                            Label(value, systemImage: "link")
                                .font(.footnote)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }
}
