import XCTest
@testable import TemplateApp

final class FeatureItemTests: XCTestCase {
    func testSamplesContainFreeAndProItems() {
        let items = FeatureItem.samples

        XCTAssertTrue(items.contains { !$0.isProFeature })
        XCTAssertTrue(items.contains { $0.isProFeature })
    }
}
