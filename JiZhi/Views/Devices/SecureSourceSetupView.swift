import SwiftUI
import UniformTypeIdentifiers

struct SecureSourceSetupView: View {
    let service: SecureDeviceService
    @Environment(AppEnvironment.self) private var environment
    @State private var name = ""
    @State private var model = SecureSourceService()
    var body: some View {
        Form {
            TextField("Source name", text: $name)
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if let config = model.configuration {
                ShareLink(item: SenderConfiguration(json: config), preview: SharePreview(Text("Sender configuration"))) {
                    Label("Export sender configuration", systemImage: "square.and.arrow.up")
                }
                Text("This configuration contains private credentials. Share only with your own sender.")
                    .foregroundStyle(.secondary)
            } else {
                Button("Create encrypted source") {
                    Task { await model.create(name: name, service: service, environment: environment) }
                }
                .disabled(model.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("New encrypted source")
    }
}

private struct SenderConfiguration: Transferable {
    let json: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { Data($0.json.utf8) }
            .suggestedFileName("pushnow-sender.json")
    }
}
