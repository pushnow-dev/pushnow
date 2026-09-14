import XCTest
@testable import JiZhi

final class AppTimestampTests: XCTestCase {
    func testReadableDatesRespectSelectedTimezoneAndYear() {
        let now = AppTimestamp.parse("2026-09-13T01:00:00Z")!
        let locale = Locale(identifier: "en")
        let today = AppTimestamp.readable("2026-09-12T23:00:00Z", timezoneIdentifier: "Asia/Shanghai", now: now, locale: locale)
        let yesterday = AppTimestamp.readable("2026-09-12T23:00:00Z", timezoneIdentifier: "UTC", now: now, locale: locale)
        XCTAssertTrue(today.hasPrefix("Today "))
        XCTAssertTrue(yesterday.hasPrefix("Yesterday "))
        XCTAssertFalse(today.contains("GMT"))
        XCTAssertTrue(AppTimestamp.readable("2025-09-12T23:00:00Z", timezoneIdentifier: "UTC", now: now, locale: locale).contains("2025"))
        XCTAssertEqual(AppTimestamp.readable("invalid", timezoneIdentifier: "UTC", now: now, locale: locale), "—")
    }

    func testISOFormatsAndInvalidInput() {
        XCTAssertEqual(AppTimestamp.parse("2026-09-13T00:00:00Z"), AppTimestamp.parse("2026-09-13T00:00:00.000Z"))
        XCTAssertNil(AppTimestamp.parse("invalid"))
        XCTAssertEqual(AppTimestamp.relative("invalid"), "—")
    }

    func testRelativeThresholdsWithFixedClock() {
        let now = AppTimestamp.parse("2026-09-13T12:00:00Z")!
        let locale = Locale(identifier: "en_US")
        for (seconds, expected) in [(300, "5 minutes ago"), (14400, "4 hours ago"), (21600, "6 hours ago"), (259200, "3 days ago")] {
            let value = ISO8601DateFormatter().string(from: now.addingTimeInterval(-Double(seconds)))
            XCTAssertEqual(AppTimestamp.relative(value, now: now, locale: locale), expected)
        }
        XCTAssertEqual(AppTimestamp.relative("2026-09-13T11:59:00Z", now: now, locale: locale), "1 minute ago")
    }

    func testTimezoneDateBoundaryAndDaylightSaving() {
        let chinese = AppTimestamp.full("2026-09-12T20:01:02Z", timezoneIdentifier: "Asia/Shanghai", locale: Locale(identifier: "zh-Hans"))
        let english = AppTimestamp.full("2026-09-12T20:01:02Z", timezoneIdentifier: "Asia/Shanghai", locale: Locale(identifier: "en-US"))
        XCTAssertTrue(chinese.contains("13"))
        XCTAssertTrue(chinese.contains("GMT+08:00 · Asia/Shanghai"))
        XCTAssertNotEqual(chinese, english)
        XCTAssertTrue(AppTimestamp.full("2026-01-01T12:00:00Z", timezoneIdentifier: "America/New_York").contains("GMT-05:00"))
        XCTAssertTrue(AppTimestamp.full("2026-07-01T12:00:00Z", timezoneIdentifier: "America/New_York").contains("GMT-04:00"))
        XCTAssertEqual(AppTimestamp.validatedZone("not-a-zone"), "system")
    }

    @MainActor func testTimezonePersistenceAndFallback() {
        let name = "timezone-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.timezoneIdentifier, "system")
        preferences.timezoneIdentifier = "Asia/Tokyo"
        XCTAssertEqual(AppPreferences(defaults: defaults).timezoneIdentifier, "Asia/Tokyo")
        preferences.timezoneIdentifier = "invalid"
        XCTAssertEqual(preferences.timezoneIdentifier, "system")
        XCTAssertEqual(AppPreferences(defaults: defaults).timezoneIdentifier, "system")
        defaults.set("invalid", forKey: AppTimestamp.timezoneKey)
        XCTAssertEqual(AppPreferences(defaults: defaults).timezoneIdentifier, "system")
    }
}
