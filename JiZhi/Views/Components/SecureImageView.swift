import SwiftUI

struct SecureImageView: View {
    let context: SecureIconContext
    var compact = false
    @Environment(AppEnvironment.self) private var environment
    @State private var model = SecureImageModel()

    var body: some View {
        Group {
            if let image = model.image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if compact {
                PushNowAppIcon()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: compact ? 40 : .infinity, maxHeight: compact ? 40 : 320)
        .frame(width: compact ? 40 : nil, height: compact ? 40 : 240)
        .accessibilityLabel(context.attachment.name)
        .task(id: context.attachment.id) { await model.load(context, environment: environment) }
        .onChange(of: environment.authService.generation) { model.image = nil }
    }
}
