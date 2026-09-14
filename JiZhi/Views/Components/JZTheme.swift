import SwiftUI
import UIKit

enum JZColor {
    static let background = Color.adaptive(light: 0xFFFFFF, dark: 0x0D1117)
    static let grouped = Color.adaptive(light: 0xF6F8FA, dark: 0x161B22)
    static let elevated = Color.adaptive(light: 0xFFFFFF, dark: 0x21262D)
    static let divider = Color.adaptive(light: 0xD1D9E0, dark: 0x30363D)
    static let text = Color.adaptive(light: 0x1F2328, dark: 0xF0F6FC)
    static let muted = Color.adaptive(light: 0x59636E, dark: 0x8B949E)
    static let primary = Color.adaptive(light: 0x25292E, dark: 0xF0F6FC)
    static let inverseText = Color.adaptive(light: 0xFFFFFF, dark: 0x0D1117)
    static let blue = Color.adaptive(light: 0x0969DA, dark: 0x58A6FF)
    static let amber = Color.adaptive(light: 0x9A6700, dark: 0xD29922)
    static let amberSoft = Color.adaptive(light: 0xFFF8C5, dark: 0x332B00)
    static let red = Color.adaptive(light: 0xD1242F, dark: 0xFF7B72)
    static let redSoft = Color.adaptive(light: 0xFFEBE9, dark: 0x3D1117)
    static let green = Color.adaptive(light: 0x1A7F37, dark: 0x3FB950)
    static let greenSoft = Color.adaptive(light: 0xDAFBE1, dark: 0x0F2A16)
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static func adaptive(light: UInt, dark: UInt, opacity: Double = 1) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                UIColor(hex: traitCollection.userInterfaceStyle == .dark ? dark : light, opacity: opacity)
            }
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, opacity: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}

extension View {
    func jzCardStyle() -> some View {
        padding(14)
            .background(JZColor.elevated)
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(JZColor.divider.opacity(0.7), lineWidth: 1)
            }
    }
}
