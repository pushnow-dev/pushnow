import SwiftUI

struct DiscoverySubscriptionEditor: View {
    let channel: DiscoverChannel
    @Bindable var model: DiscoverySubscriptionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DiscoverySubscription
    @State private var confirmingRemoval = false

    init(channel: DiscoverChannel, model: DiscoverySubscriptionsViewModel) {
        self.channel = channel
        self.model = model
        _draft = State(initialValue: model.subscription(for: channel.id) ?? DiscoverySubscription(channelID: channel.id))
    }

    private var saved: Bool { model.subscription(for: channel.id) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(DiscoveryCopy.text(channel.title)).font(.headline)
                    Text(DiscoveryCopy.text(channel.summary)).foregroundStyle(.secondary)
                    Text(DiscoverySubscriptionCopy.text(
                        "Delivery is not active. These preferences are saved only on this device for your account."
                    )).font(.footnote).foregroundStyle(.secondary)
                    if saved {
                        Label(DiscoverySubscriptionCopy.text("Saved locally - pending activation"), systemImage: "clock")
                    }
                }
                preferences
                if let error = model.errorKey {
                    Text(DiscoverySubscriptionCopy.text(error)).foregroundStyle(.red)
                }
                Section {
                    Button {
                        if model.save(draft) { dismiss() }
                    } label: {
                        Text(DiscoverySubscriptionCopy.text(saved ? "Save changes" : "Save subscription"))
                    }.disabled(!model.loaded || !model.isCurrentAccount)
                    if saved {
                        Button(role: .destructive) { confirmingRemoval = true } label: {
                            Label(DiscoverySubscriptionCopy.text("Unsubscribe"), systemImage: "minus.circle")
                        }.disabled(!model.isCurrentAccount)
                    }
                }
            }
            .navigationTitle(Text(verbatim: DiscoverySubscriptionCopy.text(saved ? "Edit subscription" : "Save subscription")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(DiscoverySubscriptionCopy.text("Cancel")) }
                }
            }
            .confirmationDialog(DiscoverySubscriptionCopy.text("Remove saved subscription?"),
                isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button(role: .destructive) {
                    if model.unsubscribe(channelID: channel.id) { dismiss() }
                } label: { Text(DiscoverySubscriptionCopy.text("Unsubscribe")) }
            } message: { Text(DiscoverySubscriptionCopy.text("This removes the preference from this device only.")) }
        }
        .onChange(of: model.isCurrentAccount) { if !model.isCurrentAccount { dismiss() } }
    }

    private var preferences: some View {
        Section {
            Toggle(isOn: $draft.wantsNotification) { Text(DiscoverySubscriptionCopy.text("Daily notification")) }
            if draft.wantsNotification {
                DatePicker(selection: $draft.pickerDate, displayedComponents: .hourAndMinute) {
                    Text(DiscoverySubscriptionCopy.text("Daily time"))
                }
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .environment(\.calendar, DiscoverySubscription.pickerCalendar)
            } else { Text(DiscoverySubscriptionCopy.text("In-app only")).foregroundStyle(.secondary) }
            NavigationLink {
                DiscoveryTimeZonePicker(selection: $draft.timeZoneID).localizedNavigationBack()
            } label: {
                LabeledContent { Text(draft.timeZoneID).multilineTextAlignment(.trailing) }
                    label: { Text(DiscoverySubscriptionCopy.text("Timezone")) }
            }
        }
    }
}

private struct DiscoveryTimeZonePicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var zones: [String] {
        Set(TimeZone.knownTimeZoneIdentifiers + [selection]).sorted().filter {
            search.isEmpty || $0.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(zones, id: \.self) { zone in
            Button {
                selection = zone
                dismiss()
            } label: {
                HStack {
                    Text(zone).foregroundStyle(.primary)
                    Spacer()
                    if zone == selection { Image(systemName: "checkmark").accessibilityHidden(true) }
                }
            }
            .accessibilityAddTraits(zone == selection ? [.isSelected] : [])
        }
        .searchable(text: $search, prompt: Text(DiscoverySubscriptionCopy.text("Search timezones")))
        .navigationTitle(Text(verbatim: DiscoverySubscriptionCopy.text("Timezone")))
    }
}
