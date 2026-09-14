import Foundation

enum AppTimestamp {
    static let timezoneKey = "pushnow.timezone"
    static func validatedZone(_ identifier: String) -> String {
        identifier == "system" || TimeZone.knownTimeZoneIdentifiers.contains(identifier) ? identifier : "system"
    }
    static func zone(_ identifier: String) -> TimeZone {
        identifier == "system" ? .autoupdatingCurrent : TimeZone(identifier: identifier) ?? .autoupdatingCurrent
    }
    static func parse(_ value: String) -> Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: value) { return date }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value)
    }
    static func relative(_ value: String, now: Date = Date(), locale: Locale = AppLocalization.locale) -> String {
        guard let date = parse(value) else { return "—" }
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 {
            return AppLocalization.text("Just now", locale: locale)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        let component: Calendar.Component = seconds < 3600 ? .minute : seconds < 86400 ? .hour : .day
        let divisor: Double = component == .minute ? 60 : component == .hour ? 3600 : 86400
        return formatter.localizedString(from: DateComponents(value: -Int(seconds / divisor), component: component))
    }
    static func full(_ value: String, timezoneIdentifier: String, locale: Locale = AppLocalization.locale) -> String {
        guard let date = parse(value) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone(timezoneIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMdjmmss")
        let offset = DateFormatter()
        offset.locale = Locale(identifier: "en_US_POSIX")
        offset.timeZone = formatter.timeZone
        offset.dateFormat = "XXXXX"
        return "\(formatter.string(from: date)) · GMT\(offset.string(from: date)) · \(formatter.timeZone.identifier)"
    }

    static func readable(_ value: String, timezoneIdentifier: String, now: Date = Date(),
                         locale: Locale = AppLocalization.locale) -> String {
        guard let date = parse(value) else { return "—" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone(timezoneIdentifier)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let day: String?
        if calendar.isDate(date, inSameDayAs: now) { day = "Today" }
        else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                calendar.isDate(date, inSameDayAs: yesterday) { day = "Yesterday" }
        else { day = nil }
        if let day {
            formatter.setLocalizedDateFormatFromTemplate("jmm")
            return "\(AppLocalization.text(day, locale: locale)) \(formatter.string(from: date))"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMdjmm" : "yyyyMMMdjmm")
        return formatter.string(from: date)
    }
}

private extension DateComponents {
    init(value: Int, component: Calendar.Component) {
        self.init()
        setValue(value, for: component)
    }
}
