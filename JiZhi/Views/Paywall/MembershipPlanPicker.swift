import SwiftUI

struct MembershipPlanPicker: View {
    @Binding var selectedPlan: MembershipPlan
    var price: (MembershipPlan) -> String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(MembershipPlan.allCases) { plan in
                Button { selectedPlan = plan } label: {
                    VStack(spacing: 12) {
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPlan == plan ? JZColor.blue : JZColor.muted)
                        Text(plan.title).font(.headline)
                        Group {
                            if plan == .free { Text("免费") }
                            else if let amount = price(plan) { Text(verbatim: amount) }
                            else { Text("Unavailable") }
                        }
                        .font(.subheadline.weight(.semibold))
                        .minimumScaleFactor(0.7)
                        Text(LocalizedStringKey(plan == .free ? "No subscription" : "Monthly"))
                            .font(.caption2).foregroundStyle(JZColor.muted)
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(JZColor.text)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: 152)
                    .background(selectedPlan == plan ? JZColor.blue.opacity(0.08) : JZColor.elevated, in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedPlan == plan ? JZColor.blue : JZColor.divider, lineWidth: selectedPlan == plan ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedPlan == plan ? .isSelected : [])
            }
        }
    }
}
