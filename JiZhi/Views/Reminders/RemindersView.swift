import SwiftUI

struct RemindersView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel = RemindersViewModel()

    private let filters = ["即将提醒", "已延后", "循环", "记录"]

    var body: some View {
        VStack(spacing: 0) {
            CompactNavBar(title: "提醒", trailingSystemImage: "ellipsis")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if environment.authService.isVerified {
                        filterBar
                        activeTimeline
                        cancelledTimeline
                    } else {
                        AuthRequiredStateView {
                            router.push(.auth)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .background(JZColor.background)
        .task { await viewModel.load(repository: environment.repository) }
        .onChange(of: environment.authService.isVerified) {
            Task { await viewModel.load(repository: environment.repository) }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        FilterChip(title: filter, isSelected: viewModel.selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var activeTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedDays, id: \.self) { day in
                Text(verbatim: AppLocalization.text(day, locale: environment.preferences.locale))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JZColor.text)

                ForEach(viewModel.activeReminders.filter { $0.day == day }) { reminder in
                    ReminderRow(reminder: reminder)
                }
            }
        }
    }

    private var cancelledTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已取消")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JZColor.text)
            ForEach(viewModel.cancelledReminders) { reminder in
                ReminderRow(reminder: reminder)
                    .opacity(0.72)
            }
        }
    }

    private var groupedDays: [String] {
        viewModel.activeReminders.reduce(into: [String]()) { days, reminder in
            if !days.contains(reminder.day) { days.append(reminder.day) }
        }
    }
}

private struct ReminderRow: View {
    @Environment(\.locale) private var locale
    let reminder: ReminderEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(reminder.time)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JZColor.text)
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JZColor.text)
                Label {
                    Text(reminder.source)
                } icon: {
                    if reminder.icon.isEmpty { PushNowAppIcon(size: 16) }
                    else { Image(systemName: reminder.icon) }
                }
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
                Label(AppLocalization.text(reminder.isCancelled ? "已取消" : "App 推送", locale: locale), systemImage: "bell")
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
            }

            Spacer()

            if let badge = reminder.badge {
                StatusBadge(title: AppLocalization.text(badge, locale: locale), tint: reminder.priority.tint, background: reminder.priority.background)
            }
        }
        .jzCardStyle()
    }
}

#Preview {
    RemindersView()
        .environment(AppEnvironment.preview())
}
