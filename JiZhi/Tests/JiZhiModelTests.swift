import XCTest
import SwiftUI
import UIKit
@testable import JiZhi

final class JiZhiModelTests: XCTestCase {
    @MainActor
    func testSelectedSegmentHasReadableContrastInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let background = luminance(UIColor(JZColor.primary).resolvedColor(with: traits))
            let foreground = luminance(UIColor(JZColor.inverseText).resolvedColor(with: traits))
            let contrast = (max(background, foreground) + 0.05) / (min(background, foreground) + 0.05)
            XCTAssertGreaterThan(contrast, 4.5)
            if style == .dark { XCTAssertGreaterThan(background, foreground) }
            else { XCTAssertLessThan(background, foreground) }
        }
    }

    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let values = [red, green, blue].map { value in
            let channel = Double(value)
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722
    }

    func testPriorityColorsKeepUrgencyDistinct() {
        XCTAssertEqual(JiZhiPriority.urgent.rawValue, "P0")
        XCTAssertEqual(JiZhiPriority.custom.rawValue, "P1")
        XCTAssertNotEqual(JiZhiPriority.urgent, JiZhiPriority.important)
    }

    func testPreviewInboxContainsUserBoundReminderData() async throws {
        let items = try await PreviewJiZhiRepository().loadInbox()

        XCTAssertTrue(items.contains { $0.id == "q2" && $0.reminderBadge == "5 小时后" })
        XCTAssertTrue(items.contains { $0.priority == .urgent && $0.requiresAck })
    }
}

final class InboxOrderTests: XCTestCase {
    private struct Message {
        let id: String
        let receivedAt: String?
    }

    func testCrossVersionDatesOverrideConcatenationOrder() {
        let messages = [
            Message(id: "v2:old", receivedAt: "2026-09-13T08:00:00Z"),
            Message(id: "secure:middle", receivedAt: "2026-09-13T09:00:00.100Z"),
            Message(id: "plain:new", receivedAt: "2026-09-13T18:00:00+08:00")
        ]
        XCTAssertEqual(InboxOrder.newestFirst(messages, receivedAt: \.receivedAt).map(\.id),
                       ["plain:new", "secure:middle", "v2:old"])
    }

    func testEqualAndMissingDatesKeepStableFallbackOrder() {
        let messages = [
            Message(id: "missing", receivedAt: nil),
            Message(id: "first", receivedAt: "2026-09-13T10:00:00Z"),
            Message(id: "invalid", receivedAt: "not-a-date"),
            Message(id: "second", receivedAt: "2026-09-13T10:00:00.000Z")
        ]
        XCTAssertEqual(InboxOrder.newestFirst(messages, receivedAt: \.receivedAt).map(\.id),
                       ["first", "second", "missing", "invalid"])
        XCTAssertTrue(InboxOrder.newestFirst([Message](), receivedAt: \.receivedAt).isEmpty)
    }
}
