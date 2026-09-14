import SwiftUI

struct SecureItemDetailView: View {
    let item: InboxItem
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var model = DetailViewModel()
    @State private var deleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                } else if let content = model.modules.first {
                    MessageDetailHeader(
                        title: content.title,
                        timeText: item.receivedAt.map {
                            AppTimestamp.readable($0, timezoneIdentifier: environment.preferences.timezoneIdentifier)
                        } ?? item.time,
                        sourceKind: item.sourceKind,
                        sourceType: item.sourceType,
                        sourceName: item.source
                    )
                    MessageDetailBodyText(text: content.subtitle)
                } else {
                    MessageDetailHeader(
                        title: item.title,
                        timeText: item.receivedAt.map {
                            AppTimestamp.readable($0, timezoneIdentifier: environment.preferences.timezoneIdentifier)
                        } ?? item.time,
                        sourceKind: item.sourceKind,
                        sourceType: item.sourceType,
                        sourceName: item.source
                    )
                    ProgressView().frame(maxWidth: .infinity, minHeight: 180)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(AppLocalization.text("Delete message", locale: environment.preferences.locale), systemImage: "trash", role: .destructive) {
                    deleting = true
                }
                .disabled(model.isWorking)
            }
        }
        .confirmationDialog(AppLocalization.text("Delete message", locale: environment.preferences.locale), isPresented: $deleting, titleVisibility: .visible) {
            Button(AppLocalization.text("Delete message", locale: environment.preferences.locale), role: .destructive) {
                Task {
                    if await model.delete(item: item, repository: environment.repository) {
                        router.pop()
                    }
                }
            }
            Button(AppLocalization.text("Cancel", locale: environment.preferences.locale), role: .cancel) {}
        }
        .task {
            let generation = environment.authService.generation
            await model.load(itemID: item.id, repository: environment.repository)
            guard !model.modules.isEmpty, model.errorMessage == nil,
                  generation == environment.authService.generation, !Task.isCancelled else { return }
            try? await environment.repository.markItemRead(item.id)
        }
    }
}
