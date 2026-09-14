import SwiftUI

struct DiscoverView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if let scope = DiscoveryAccountScope(session: environment.authService.session,
                generation: environment.authService.generation) {
                DiscoverySubscriptionsContent(auth: environment.authService, scope: scope).id(scope)
            } else {
                ContentUnavailableView {
                    Label(DiscoverySubscriptionCopy.text("Sign in to save subscriptions"), systemImage: "person.crop.circle")
                } description: {
                    Text(DiscoverySubscriptionCopy.text("A verified email account is required."))
                } actions: {
                    Button { router.push(.auth) } label: { Text(DiscoverySubscriptionCopy.text("Sign in")) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(JZColor.background)
    }
}

private struct DiscoverySubscriptionsContent: View {
    @State private var viewModel: DiscoverySubscriptionsViewModel
    @State private var search = ""
    @State private var selectedFilter = "All"
    @State private var selectedChannel: DiscoverChannel?

    init(auth: AuthService, scope: DiscoveryAccountScope) {
        _viewModel = State(initialValue: DiscoverySubscriptionsViewModel(auth: auth, scope: scope))
    }

    private let filters = ["All", "Saved channels", "Trending", "Daily picks", "Prices", "Technology", "Development"]

    var body: some View {
        VStack(spacing: 0) {
            CompactNavBar(title: LocalizedStringKey(DiscoverySubscriptionCopy.text("Discover")), trailingSystemImage: nil)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchField
                    filterBar
                    if let error = viewModel.errorKey {
                        Text(DiscoverySubscriptionCopy.text(error)).foregroundStyle(.red)
                        Button { viewModel.load() } label: { Text(DiscoverySubscriptionCopy.text("Retry")) }
                    }
                    channelList
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .background(JZColor.background)
        .task { viewModel.load() }
        .sheet(item: $selectedChannel) { channel in
            DiscoverySubscriptionEditor(channel: channel, model: viewModel)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(JZColor.muted)
            TextField(DiscoverySubscriptionCopy.text("Search channels"), text: $search)
                .font(.subheadline)
                .foregroundStyle(JZColor.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(JZColor.grouped, in: .rect(cornerRadius: 10))
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        FilterChip(title: DiscoverySubscriptionCopy.text(filter), isSelected: selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var channelList: some View {
        VStack(spacing: 10) {
            ForEach(filteredChannels) { channel in
                Button { selectedChannel = channel } label: {
                    DiscoverChannelRow(channel: channel, subscription: viewModel.subscription(for: channel.id))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.loaded || !viewModel.isCurrentAccount)
            }
            if filteredChannels.isEmpty {
                if selectedFilter == "Saved channels", search.isEmpty {
                    ContentUnavailableView(DiscoverySubscriptionCopy.text("No saved channels"), systemImage: "bookmark")
                } else { ContentUnavailableView.search(text: search) }
            }
        }
    }

    private var filteredChannels: [DiscoverChannel] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.channels.filter { channel in
            (selectedFilter == "Saved channels" ? viewModel.subscription(for: channel.id) != nil
                : channel.matchesDiscoveryFilter(selectedFilter)) &&
                (query.isEmpty || "\(channel.title) \(DiscoveryCopy.text(channel.title)) \(DiscoveryCopy.text(channel.summary)) \(channel.frequency)".localizedCaseInsensitiveContains(query))
        }
    }
}

private struct DiscoverChannelRow: View {
    let channel: DiscoverChannel
    let subscription: DiscoverySubscription?

    var body: some View {
        HStack(spacing: 12) {
            DiscoverPlatformIcon(channel: channel)

            VStack(alignment: .leading, spacing: 5) {
                Text(DiscoveryCopy.text(channel.title))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(DiscoveryCopy.text(channel.summary))
                    .font(.caption)
                    .foregroundStyle(JZColor.muted)
                    .lineLimit(2)
                Text(DiscoveryCopy.text(channel.badge))
                    .font(.caption2)
                    .foregroundStyle(JZColor.muted)
                if let subscription {
                    Text(DiscoverySubscriptionCopy.text("Saved locally - pending activation"))
                        .font(.caption).foregroundStyle(JZColor.muted)
                    if subscription.wantsNotification {
                        Text(subscription.pickerDate, style: .time)
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                            .font(.caption)
                        Text(subscription.timeZoneID).font(.caption).foregroundStyle(JZColor.muted)
                    } else {
                        Text(DiscoverySubscriptionCopy.text("In-app only")).font(.caption)
                    }
                }
            }

            Spacer()

            Image(systemName: subscription == nil ? "plus.circle" : "slider.horizontal.3")
                .foregroundStyle(JZColor.muted).accessibilityHidden(true)
        }
        .jzCardStyle()
    }
}

private struct DiscoverPlatformIcon: View {
    let channel: DiscoverChannel

    var body: some View {
        Group {
            if let brand = channel.discoveryBrand {
                Image(brand.asset)
                    .resizable()
                    .renderingMode(channel.id == "hackernews" ? .original : .template)
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color(red: Double((brand.hex >> 16) & 255) / 255,
                                      green: Double((brand.hex >> 8) & 255) / 255,
                                      blue: Double(brand.hex & 255) / 255))
            } else {
                Image(systemName: channel.icon)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(JZColor.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(JZColor.grouped)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}

#Preview {
    DiscoverView()
        .environment(AppEnvironment.preview())
        .environment(AppRouter())
}
