import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, english = "en", simplifiedChinese = "zh-Hans", japanese = "ja"
    case korean = "ko", spanish = "es", german = "de"

    var id: String { rawValue }
    var locale: Locale {
        Locale(identifier: self == .system ? AppLocalization.systemLanguageIdentifier : rawValue)
    }
    var nativeName: String {
        switch self {
        case .system: String(localized: "Follow system", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .german: "Deutsch"
        }
    }
}

enum AppLocalization {
    static let languageKey = "pushnow.language"
    // Locale.current can describe regional formatting in a different language
    // from the app's preferred language. Resolve one language for all UI paths.
    static var systemLanguageIdentifier: String {
        Bundle.preferredLocalizations(from: ["en", "zh-Hans", "ja", "ko", "es", "de"],
                                      forPreferences: Locale.preferredLanguages).first ?? "en"
    }
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .system
    }
    static var locale: Locale {
        language.locale
    }
    static var bundle: Bundle { localizedBundle(for: language) }
    static var notificationLanguage: AppLanguage {
        guard let data = try? SecureKeyStore().read(languageKey), let raw = String(data: data, encoding: .utf8),
              let language = AppLanguage(rawValue: raw) else { return .system }
        return language
    }
    static var notificationLocale: Locale { notificationLanguage.locale }
    static var notificationBundle: Bundle { localizedBundle(for: notificationLanguage) }

    static func localizedBundle(for language: AppLanguage) -> Bundle {
        let identifier = language == .system ? systemLanguageIdentifier : language.rawValue
        guard let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    static func text(_ key: String, locale: Locale) -> String {
        let identifier = Bundle.preferredLocalizations(from: ["en", "zh-Hans", "ja", "ko", "es", "de"],
                                                       forPreferences: [locale.identifier]).first ?? "en"
        return localizedBundle(for: AppLanguage(rawValue: identifier) ?? .english)
            .localizedString(forKey: key, value: key, table: nil)
    }

    static func text(_ key: String.LocalizationValue, language: AppLanguage) -> String {
        String(localized: key, bundle: localizedBundle(for: language), locale: language.locale)
    }
}

extension LocalizedStringResource {
    static func app(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, locale: AppLocalization.locale, bundle: .atURL(AppLocalization.bundle.bundleURL))
    }
}
