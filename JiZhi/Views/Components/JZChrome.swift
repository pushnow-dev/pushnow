import SwiftUI

struct JiZhiTabBar: View {
    @Environment(\.locale) private var locale
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(verbatim: AppLocalization.text(tab.localizationKey, locale: locale))
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selectedTab == tab ? JZColor.blue : JZColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? JZColor.grouped : .clear, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalization.text(tab.localizationKey, locale: locale))
            }
        }
        .padding(6)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(JZColor.divider.opacity(0.6), lineWidth: 1)
        }
    }
}

struct CompactNavBar: View {
    @Environment(\.locale) private var locale
    let title: LocalizedStringKey
    var showsBack: Bool = false
    var trailingSystemImage: String? = "ellipsis"
    var onBack: (() -> Void)?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack {
            if showsBack {
                IconButton(systemName: "chevron.left", action: { onBack?() })
                    .accessibilityLabel(AppLocalization.text("Back", locale: locale))
            } else {
                Spacer()
                    .frame(width: 42)
            }

            Spacer()
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(JZColor.text)
            Spacer()

            if let trailingSystemImage {
                IconButton(systemName: trailingSystemImage, action: { trailingAction?() })
            } else {
                Spacer()
                    .frame(width: 42)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

struct IconButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(JZColor.text)
                .frame(width: 38, height: 38)
                .background(JZColor.grouped, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName)
    }
}

struct FilterChip: View {
    @Environment(\.locale) private var locale
    let title: String
    var isSelected: Bool

    var body: some View {
        Text(verbatim: AppLocalization.text(title, locale: locale))
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? JZColor.inverseText : JZColor.muted)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? JZColor.primary : JZColor.grouped, in: Capsule())
    }
}

struct StatusBadge: View {
    @Environment(\.locale) private var locale
    let title: String
    var tint: Color
    var background: Color

    var body: some View {
        Text(verbatim: AppLocalization.text(title, locale: locale))
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(background, in: .rect(cornerRadius: 7))
    }
}

struct SourceIcon: View {
    let systemName: String

    var body: some View {
        if systemName.isEmpty || systemName == "lock.shield" {
            PushNowAppIcon()
        } else {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(JZColor.text)
                .frame(width: 38, height: 38)
                .background(JZColor.grouped, in: Circle())
                .overlay { Circle().stroke(JZColor.divider.opacity(0.6), lineWidth: 1) }
        }
    }
}

private struct LocalizedNavigationBack: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.backward")
                            Text(verbatim: AppLocalization.text("Back", locale: locale))
                        }
                    }
                    .accessibilityLabel(AppLocalization.text("Back", locale: locale))
                    .accessibilityIdentifier("navigation-back")
                }
            }
    }
}

extension View {
    func localizedNavigationBack() -> some View { modifier(LocalizedNavigationBack()) }
}

/// Uses the same local artwork as the installed app's icon.
struct PushNowAppIcon: View {
    var size: CGFloat = 38
    var body: some View {
        Image("PushNowBrand")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.24))
            .accessibilityLabel("PushNow")
            .accessibilityIdentifier("pushnow-default-icon")
    }
}
