import Foundation
import Observation
import UIKit

@MainActor @Observable
final class SecureImageModel {
    var image: UIImage?

    func load(_ context: SecureIconContext, environment: AppEnvironment) async {
        guard context.attachment.mime.hasPrefix("image/"), context.attachment.size <= 10 * 1024 * 1024 else { return }
        do {
            let url = try await SecureAttachmentService.retrieve(context.attachment, message: context.message,
                api: APIClient(baseURL: environment.configuration.apiBaseURL), auth: environment.authService)
            defer { try? FileManager.default.removeItem(at: url) }
            guard !Task.isCancelled else { return }
            image = UIImage(data: try Data(contentsOf: url))
        } catch { image = nil }
    }
}
