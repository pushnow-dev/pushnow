import StoreKit
import SwiftUI

struct MembershipContentView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = PaywallViewModel()
    @State private var selectedPlan: MembershipPlan = .plus
    @State private var redeemPresented = false
    @State private var redemptionError: String?
    @State private var redemptionGeneration: UUID?

    private var service: RevenueCatService { environment.revenueCatService }
    private var currentPlan: MembershipPlan { service.entitlementState.membershipPlan }
    private var busy: Bool { viewModel.isLoading || service.isLoading }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                MembershipComparisonTable(selectedPlan: selectedPlan)
                MembershipPlanPicker(selectedPlan: $selectedPlan, price: service.price(for:))
                status
                actions
                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(JZColor.background)
        .refreshable { await viewModel.refresh(service: service) }
        .task(id: environment.authService.generation) {
            viewModel.reset()
            await viewModel.refresh(service: service)
        }
        .offerCodeRedemption(isPresented: $redeemPresented) { result in
            guard redemptionGeneration == environment.authService.generation,
                  environment.authService.isVerified else { return }
            switch result {
            case .failure(let error):
                let safe = RevenueCatSDKAdapter.normalized(error)
                redemptionError = safe == .cancelled ? nil : safe.localizedDescription
            case .success: Task { await viewModel.redeemCompleted(service: service) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pushnow Membership").font(.title.bold()).foregroundStyle(JZColor.text)
            HStack {
                Label("Current plan", systemImage: "checkmark.seal")
                Text(currentPlan.title).fontWeight(.semibold)
            }
            .font(.subheadline).foregroundStyle(JZColor.muted)
        }
    }

    @ViewBuilder private var status: some View {
        if busy {
            ProgressView("Checking membership").frame(maxWidth: .infinity)
        }
        if viewModel.isPending {
            Label("Purchase awaiting approval", systemImage: "clock")
                .font(.footnote).foregroundStyle(JZColor.muted)
        }
        if service.serverSyncPending {
            HStack {
                Text("Membership sync pending. Refresh to retry.")
                    .font(.footnote).foregroundStyle(JZColor.muted)
                Spacer(minLength: 8)
                Button { Task { await viewModel.refresh(service: service) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Refresh"))
                .disabled(busy)
            }
        }
        if case .failed(let error) = viewModel.state {
            HStack {
                Text(error.localizedDescription).font(.footnote).foregroundStyle(JZColor.red)
                Spacer(minLength: 8)
                Button { Task { await viewModel.refresh(service: service) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Refresh"))
                .disabled(busy)
            }
        }
        if let redemptionError {
            Text(verbatim: redemptionError).font(.footnote).foregroundStyle(JZColor.red)
        }
    }

    private var actions: some View {
        VStack(spacing: 18) {
            Button {
                Task { await viewModel.purchase(plan: selectedPlan, service: service) }
            } label: {
                HStack {
                    Image(systemName: selectedPlan == currentPlan ? "checkmark.circle" : "crown")
                    Text(LocalizedStringKey(selectedPlan == currentPlan ? "Current plan" : selectedPlan == .free ? "Free plan" : "Continue"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent).tint(JZColor.blue)
            .disabled(busy || selectedPlan == .free || selectedPlan == currentPlan || !service.isAvailable(selectedPlan))
            HStack(spacing: 24) {
                Button {
                    Task { await viewModel.restore(service: service) }
                } label: { Label("Restore purchases", systemImage: "arrow.clockwise") }
                Button {
                    redemptionError = nil
                    redemptionGeneration = environment.authService.generation
                    redeemPresented = true
                } label: { Label("Redeem code", systemImage: "gift") }
            }
            .font(.footnote).disabled(busy || !environment.authService.isVerified)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscriptions renew automatically unless cancelled in App Store settings. Payment is charged to your Apple Account after confirmation.")
                .font(.footnote).foregroundStyle(JZColor.muted)
            HStack(spacing: 24) {
                if let url = environment.configuration.privacyPolicyURL { Link("Privacy Policy", destination: url) }
                if let url = environment.configuration.termsOfUseURL { Link("Terms of Use", destination: url) }
            }
            .font(.footnote)
        }
    }
}
