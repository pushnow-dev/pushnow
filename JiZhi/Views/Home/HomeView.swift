import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @State private var viewModel = InboxViewModel()
    @State private var pendingDelete: InboxItem?

    private let filters = ["全部", "未读", "新到结果", "即将提醒", "P0/P1", "来源"]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            filterBar
            if environment.authService.secureDevices(api: APIClient(baseURL: environment.configuration.apiBaseURL)).historyAccessPending {
                NavigationLink { DevicesView() } label: {
                    Label("Grant history access", systemImage: "key").font(.subheadline)
                }.padding(.vertical, 8)
            }
            content
        }
        .background(JZColor.background)
        .modifier(HomeRefreshModifier(model: viewModel))
        .onReceive(NotificationCenter.default.publisher(for: SecureHistoryEvent.name)) { notification in
            guard let event = notification.object as? SecureHistoryEvent,
                  event.user == environment.authService.session?.userID else { return }
            viewModel.apply(event)
        }
        .confirmationDialog(
            AppLocalization.text("Delete message", locale: environment.preferences.locale),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("Delete message", locale: environment.preferences.locale), role: .destructive) {
                guard let item = pendingDelete else { return }
                pendingDelete = nil
                Task { await viewModel.delete(item: item, repository: environment.repository) }
            }
            Button(AppLocalization.text("Cancel", locale: environment.preferences.locale), role: .cancel) {
                pendingDelete = nil
            }
        }
    }

    private var topBar: some View {
        HStack {
            IconButton(systemName: "person.crop.circle") {
                router.push(.settings)
            }
            .accessibilityLabel("设置")
            .accessibilityIdentifier("home-settings")

            Spacer()

            Text(environment.configuration.displayName)
                .font(.headline.weight(.semibold))

            Spacer()

            HStack(spacing: 10) {
                IconButton(systemName: "magnifyingglass") { }
                IconButton(systemName: "plus") {
                    if environment.authService.isVerified {
                        router.selectedTab = .sources
                    } else {
                        router.push(.auth)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    if filter == "来源" {
                        Menu {
                            ForEach(HomeSourceFilter.allCases) { source in
                                Button {
                                    viewModel.selectedFilter = filter
                                    viewModel.selectedSourceFilter = source
                                } label: {
                                    Label(source.localizedTitle(locale: locale), systemImage: source.iconName)
                                }
                            }
                        } label: {
                            FilterChip(title: sourceFilterTitle, isSelected: viewModel.selectedFilter == filter)
                        }
                    } else {
                        Button {
                            viewModel.selectedFilter = filter
                        } label: {
                            FilterChip(title: filter, isSelected: viewModel.selectedFilter == filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var sourceFilterTitle: String {
        viewModel.selectedFilter == "来源"
            ? viewModel.selectedSourceFilter.localizedTitle(locale: locale)
            : "来源"
    }

    @ViewBuilder
    private var content: some View {
        if !environment.authService.isVerified {
            AuthRequiredStateView {
                router.push(.auth)
            }
        } else {
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(title: "正在加载")
        case .failed(let error):
            ScrollView {
                ErrorStateView(message: error.localizedDescription) {
                    Task { await viewModel.load(repository: environment.repository, accountGeneration: environment.authService.generation) }
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { await viewModel.load(repository: environment.repository, accountGeneration: environment.authService.generation) }
        case .loaded:
            List {
                    if viewModel.selectedFilter == "未读", viewModel.items.isEmpty {
                        ContentUnavailableView(
                            AppLocalization.text("No unread messages", locale: environment.preferences.locale),
                            systemImage: "checkmark.circle",
                            description: Text(verbatim: AppLocalization.text("Messages you open are marked as read.", locale: environment.preferences.locale))
                        )
                        .padding(.top, 24)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    if let error = viewModel.refreshError {
                        HStack(spacing: 12) {
                            Text(error.localizedDescription)
                                .font(.footnote).foregroundStyle(JZColor.muted)
                            Spacer(minLength: 0)
                            Button {
                                Task { await viewModel.load(repository: environment.repository, accountGeneration: environment.authService.generation) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("重试")
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(viewModel.items) { item in
                        InboxItemRow(item: item) {
                            router.push(.itemDetail(item))
                        }
                        .disabled(viewModel.deletingIDs.contains(item.id))
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDelete = item
                            } label: {
                                Label(AppLocalization.text("Delete message", locale: environment.preferences.locale), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDelete = item
                            } label: {
                                Label(AppLocalization.text("Delete message", locale: environment.preferences.locale), systemImage: "trash")
                            }
                        }
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { await viewModel.load(repository: environment.repository, accountGeneration: environment.authService.generation) }
        }
    }
}

private struct InboxItemRow: View {
    @Environment(\.locale) private var locale
    let item: InboxItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.unread ? JZColor.blue : .clear)
                    .frame(width: 8, height: 8)
                    .padding(.top, 20)

                if let context = item.secureIcon { SecureImageView(context: context, compact: true) }
                else { SourceIcon(systemName: item.displayIcon) }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JZColor.text)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            Text(item.receivedAt.map { AppTimestamp.relative($0, now: context.date, locale: locale) } ?? item.time)
                                .font(.caption)
                                .foregroundStyle(JZColor.muted)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(JZColor.muted)
                        .lineLimit(2)
                    MessageSourceBadge(kind: item.sourceKind, sourceType: item.sourceType,
                                       name: item.source, compact: true)
                    if item.priority == .urgent || item.reminderBadge != nil {
                        HStack(spacing: 8) {
                            priorityBadge
                            reminderBadge
                        }
                    }
                }
            }
            .padding(.vertical, 14)
            .contentShape(.rect)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(JZColor.divider.opacity(0.65))
                    .frame(height: 1)
                    .padding(.leading, 58)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("inbox-item-\(item.id)")
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if item.priority == .urgent {
            StatusBadge(title: item.priority.rawValue, tint: item.priority.tint, background: item.priority.background)
        }
    }

    @ViewBuilder
    private var reminderBadge: some View {
        if let reminderBadge = item.reminderBadge {
            StatusBadge(title: reminderBadge, tint: JZColor.amber, background: JZColor.amberSoft)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppEnvironment.preview())
        .environment(AppRouter())
}
