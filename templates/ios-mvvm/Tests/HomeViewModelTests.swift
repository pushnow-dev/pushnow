import XCTest
@testable import TemplateApp

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoadPublishesItems() async {
        let viewModel = HomeViewModel()

        await viewModel.load(repository: InMemoryFeatureRepository())

        XCTAssertEqual(viewModel.items, FeatureItem.samples)
    }
}
