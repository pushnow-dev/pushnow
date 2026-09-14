import Foundation
import Observation

@MainActor @Observable
final class SecureV2DetailModel {
    var message: SecureV2Message?
    var content: SecureV2Content?
    var error: String?
    var busy = false
    var previewURL: URL?
    var markdown: SecureMarkdownDocument?
    var renderedAttachments: [SecureRenderedAttachment] = []
    var downloadURLs: [String: URL] = [:]
    var attachmentBusyIDs: Set<String> = []

    func load(id: String, environment: AppEnvironment) async {
        let generation = environment.authService.generation
        let itemID = "v2:\(id)"
        if let cached = NotificationHistoryCache.message(id: id, auth: environment.authService) {
            message = cached.message
            content = cached.content
            environment.repository.recordItemRead(itemID)
        }
        busy = true
        defer { busy = false }
        do {
            let api = APIClient(baseURL: environment.configuration.apiBaseURL)
            let result = try await SecureV2Inbox.message(id: id, api: api, auth: environment.authService)
            guard generation == environment.authService.generation, !Task.isCancelled else { return }
            message = result.0
            content = result.1
            // Reading succeeds once verified content is visible, even if sync fails.
            try? await environment.repository.markItemRead(itemID)
        } catch {
            guard generation == environment.authService.generation else { return }
            if !NotificationHistoryCache.isOffline(error) { content = nil }
            self.error = AppError(error).localizedDescription
        }
    }

    func open(_ attachment: SecureAttachment, environment: AppEnvironment) async {
        guard let url = await download(attachment, environment: environment) else { return }
        do {
            if attachment.isMarkdown {
                markdown = try SecureMarkdownDocument(url: url, name: attachment.name)
            } else {
                previewURL = url
            }
        } catch { self.error = AppError(error).localizedDescription }
    }

    @discardableResult
    func download(_ attachment: SecureAttachment, environment: AppEnvironment) async -> URL? {
        guard let message else { return nil }
        if let url = downloadURLs[attachment.id] { return url }
        attachmentBusyIDs.insert(attachment.id)
        defer { attachmentBusyIDs.remove(attachment.id) }
        do {
            let url = try await SecureAttachmentService.retrieve(attachment, message: message,
                api: APIClient(baseURL: environment.configuration.apiBaseURL), auth: environment.authService)
            downloadURLs[attachment.id] = url
            return url
        } catch {
            self.error = AppError(error).localizedDescription
            return nil
        }
    }

    func renderInlineAttachments(environment: AppEnvironment) async {
        guard let content else { return }
        for attachment in content.attachments where attachment.isInlineRenderable {
            guard !renderedAttachments.contains(where: { $0.id == attachment.id }),
                  !attachmentBusyIDs.contains(attachment.id),
                  let url = await download(attachment, environment: environment) else { continue }
            do {
                let document = attachment.isMarkdown ? try SecureMarkdownDocument(url: url, name: attachment.name) : nil
                renderedAttachments.append(SecureRenderedAttachment(attachment: attachment, url: url, markdown: document))
            } catch {
                self.error = AppError(error).localizedDescription
            }
        }
    }

    func delete(environment: AppEnvironment) async -> Bool {
        guard let message else { return false }
        do {
            try await SecureV2Inbox.delete(id: message.messageId, api: APIClient(baseURL: environment.configuration.apiBaseURL),
                auth: environment.authService)
            content = nil
            previewURL = nil
            renderedAttachments = []
            downloadURLs = [:]
            return true
        } catch { self.error = AppError(error).localizedDescription; return false }
    }

    func clearFiles() {
        if let message { SecureAttachmentService.removeFiles(user: message.userId, message: message.messageId) }
        previewURL = nil
        markdown = nil
        renderedAttachments = []
        downloadURLs = [:]
        attachmentBusyIDs = []
    }
}

struct SecureRenderedAttachment: Identifiable {
    var attachment: SecureAttachment
    var url: URL
    var markdown: SecureMarkdownDocument?

    var id: String { attachment.id }
}

extension SecureAttachment {
    var isImage: Bool { mime.lowercased().hasPrefix("image/") }

    var isMarkdown: Bool {
        let value = mime.lowercased()
        return ["text/markdown", "text/x-markdown", "application/markdown"].contains(value)
            || name.lowercased().hasSuffix(".md")
            || name.lowercased().hasSuffix(".markdown")
    }

    var isPDF: Bool {
        mime.lowercased() == "application/pdf" || name.lowercased().hasSuffix(".pdf")
    }

    var isInlineRenderable: Bool { isImage || isMarkdown || isPDF }

    var iconName: String {
        if isImage { return "photo" }
        if isPDF { return "doc.richtext" }
        if isMarkdown { return "text.alignleft" }
        return "paperclip"
    }
}
