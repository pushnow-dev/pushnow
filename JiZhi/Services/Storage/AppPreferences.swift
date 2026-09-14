import Foundation
import Observation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var title: LocalizedStringResource {
        switch self {
        case .system: .app("Follow system")
        case .light: .app("Light")
        case .dark: .app("Dark")
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults
    private static let appearanceKey = "pushnow.appearance"
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: AppLocalization.languageKey)
            if defaults === UserDefaults.standard {
                try? SecureKeyStore().write(Data(language.rawValue.utf8), account: AppLocalization.languageKey)
            }
        }
    }
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    var locale: Locale { language.locale }
    private var storedTimezoneIdentifier: String
    var timezoneIdentifier: String {
        get { storedTimezoneIdentifier }
        set {
            let identifier = AppTimestamp.validatedZone(newValue)
            storedTimezoneIdentifier = identifier
            defaults.set(identifier, forKey: AppTimestamp.timezoneKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        storedTimezoneIdentifier = AppTimestamp.validatedZone(defaults.string(forKey: AppTimestamp.timezoneKey) ?? "system")
        language = AppLanguage(rawValue: defaults.string(forKey: AppLocalization.languageKey) ?? "") ?? .system
        appearance = AppAppearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "") ?? .system
        if defaults === UserDefaults.standard {
            try? SecureKeyStore().write(Data(language.rawValue.utf8), account: AppLocalization.languageKey)
        }
    }
}
