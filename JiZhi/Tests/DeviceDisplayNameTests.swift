import XCTest
@testable import JiZhi

final class DeviceDisplayNameTests: XCTestCase {
    func testAvailableSystemNameIncludesHardwareModel() {
        XCTAssertEqual(name(system: "Travel phone"), "Travel phone (iPhone 15 Pro)")
    }

    func testRestrictedSystemNameStillIdentifiesModelAndInstallation() {
        XCTAssertEqual(name(system: "iPhone"), "iPhone 15 Pro (ABC123)")
        XCTAssertNotEqual(name(system: "iPhone"), name(system: "iPhone", installation: "def456"))
    }

    func testRegisteredRenameSurvivesSystemNameChanges() {
        XCTAssertEqual(name(system: "New system name", existing: "Work alerts"), "Work alerts")
    }

    func testNameAlreadyContainingModelDoesNotDuplicateModel() {
        XCTAssertEqual(name(system: "Travel iPhone 15 Pro"), "Travel iPhone 15 Pro")
    }

    func testUnknownHardwareRetainsExactCode() {
        XCTAssertEqual(name(system: "iPhone", identifier: "iPhone99,1"), "iPhone iPhone99,1 (ABC123)")
    }

    func testLongUnicodeNameFitsServerUTF16LimitAndRetainsModel() {
        let result = name(system: String(repeating: "\u{1F680}", count: 100))
        XCTAssertLessThanOrEqual(result.utf16.count, 80)
        XCTAssertTrue(result.hasSuffix(" (iPhone 15 Pro)"))
    }

    private func name(system: String, existing: String? = nil, identifier: String = "iPhone16,1",
                      installation: String = "abc123-456") -> String {
        DeviceDisplayName.compose(existingName: existing, systemName: system,
            hardwareIdentifier: identifier, family: "iPhone", installationID: installation)
    }
}
