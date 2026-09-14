import SwiftUI

struct ItemDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = DetailViewModel()
    @State private var deleting = false

    let item: InboxItem

    var body: some View {
        if item.id.hasPrefix("v2:") {
            SecureV2DetailView(id: String(item.id.dropFirst(3)))
        } else if item.id.hasPrefix("secure:") {
            SecureItemDetailView(item: item)
        } else {
            legacyBody
        }
    }

    private var legacyBody: some View {
        VStack(spacing: 0) {
            CompactNavBar(
                title: "",
                showsBack: true,
                trailingSystemImage: "trash",
                onBack: router.pop,
                trailingAction: { deleting = true }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    bodyText
                    errorText
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .background(JZColor.background)
        .task {
            // Legacy content is already visible from the inbox snapshot.
            try? await environment.repository.markItemRead(item.id)
            await viewModel.load(itemID: item.id, repository: environment.repository)
        }
        .confirmationDialog(AppLocalization.text("Delete message", locale: environment.preferences.locale), isPresented: $deleting, titleVisibility: .visible) {
            Button(AppLocalization.text("Delete message", locale: environment.preferences.locale), role: .destructive) {
                Task {
                    if await viewModel.delete(item: item, repository: environment.repository) {
                        router.pop()
                    }
                }
            }
            Button(AppLocalization.text("Cancel", locale: environment.preferences.locale), role: .cancel) {}
        }
    }

    private var titleBlock: some View {
        MessageDetailHeader(
            title: item.title,
            timeText: item.receivedAt.map {
                AppTimestamp.readable($0, timezoneIdentifier: environment.preferences.timezoneIdentifier)
            } ?? item.time,
            sourceKind: item.sourceKind,
            sourceType: item.sourceType,
            sourceName: item.source
        )
    }

    private var bodyText: some View {
        MessageDetailBodyText(text: item.summary)
    }

    @ViewBuilder
    private var errorText: some View {
        if let message = viewModel.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(JZColor.red)
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: try! PreviewJiZhiRepository().loadInboxSync().first!)
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}

private extension PreviewJiZhiRepository {
    func loadInboxSync() throws -> [InboxItem] {
        [
            .init(id: "q2", source: "Research Agent", category: "AI 趋势报告", title: "Q2 竞品分析已完成", summary: "包含报告、表格和 3 个附件", time: "15:12", icon: "doc.text", unread: true, priority: .important, reminderBadge: "5 小时后", requiresAck: true, pushEnabled: true)
        ]
    }
}
