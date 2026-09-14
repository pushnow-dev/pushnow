import SwiftUI

struct MembershipComparisonTable: View {
    let selectedPlan: MembershipPlan

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("Features").font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                ForEach(MembershipPlan.allCases) { plan in
                    Text(plan.title).font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(background(plan))
                }
            }
            row("Notifications / day", values: ["50", "500", "Unlimited"])
            feature("Encrypted push")
            feature("Multiple devices")
            feature("Message history")
            feature("HTTP & CLI")
        }
        .foregroundStyle(JZColor.text)
        .padding(.horizontal, 10)
        .background(JZColor.elevated, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(JZColor.divider))
    }

    private func row(_ title: LocalizedStringKey, values: [LocalizedStringKey]) -> some View {
        GridRow {
            Text(title).font(.caption).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            ForEach(Array(MembershipPlan.allCases.enumerated()), id: \.element.id) { index, plan in
                Text(values[index]).font(.caption.weight(.semibold))
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(background(plan))
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(JZColor.divider).frame(height: 0.5) }
    }

    private func feature(_ title: LocalizedStringKey) -> some View {
        GridRow {
            Text(title).font(.caption).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            ForEach(MembershipPlan.allCases) { plan in
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(JZColor.green)
                    .accessibilityLabel("Included")
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(background(plan))
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(JZColor.divider).frame(height: 0.5) }
    }

    private func background(_ plan: MembershipPlan) -> Color {
        plan == selectedPlan ? JZColor.blue.opacity(0.09) : .clear
    }
}
