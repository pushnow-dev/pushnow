import Foundation
import XCTest
@testable import JiZhi

@MainActor
final class SecureV2WorkflowTests: XCTestCase {
    func testInboxIconsDefaultToAppAndPreserveCustomSymbols() {
        var item = InboxItem(id: "test", source: "Encrypted source", category: "Encrypted",
            title: "武汉今日天气｜9月13日", summary: "", time: "", icon: "lock.shield",
            unread: true, priority: .normal, requiresAck: false, pushEnabled: true)
        XCTAssertEqual(item.displayIcon, "")
        item.title = "WEATHER forecast"
        XCTAssertEqual(item.displayIcon, "")
        item.title = "Build completed"
        XCTAssertEqual(item.displayIcon, "")
        item.title = "Meeting reminder"
        XCTAssertEqual(item.displayIcon, "")
        item.title = "New message"
        XCTAssertEqual(item.displayIcon, "")
        item.icon = "paperplane"
        XCTAssertEqual(item.displayIcon, "paperplane")
    }

    func testPairingCodeBindsAccountDeviceKeyAndIdentity() {
        let code = SecureCrypto.pairingCode(user: "a", device: "b", publicKey: "c", identity: "d")
        XCTAssertEqual(code.count, 19)
        XCTAssertEqual(code, SecureCrypto.pairingCode(user: "a", device: "b", publicKey: "c", identity: "d"))
        XCTAssertNotEqual(code, SecureCrypto.pairingCode(user: "other", device: "b", publicKey: "c", identity: "d"))
        XCTAssertNotEqual(code, SecureCrypto.pairingCode(user: "a", device: "other", publicKey: "c", identity: "d"))
        XCTAssertNotEqual(code, SecureCrypto.pairingCode(user: "a", device: "b", publicKey: "other", identity: "d"))
        XCTAssertNotEqual(code, SecureCrypto.pairingCode(user: "a", device: "b", publicKey: "c", identity: "other"))
    }
    func testLookupPreparesArchiveBeforeAttemptingAuthorizationRequest() async {
        var prepared = false
        let model = SenderAuthorizationService { _ in
            prepared = true
            throw SecureFailure.pending
        }
        let api = APIClient(baseURL: URL(string: "https://unused.invalid")!)
        let service = SecureDeviceService(api: api, auth: AuthService(apiClient: nil))
        await model.lookup(code: "7PWM248G", device: service)
        XCTAssertTrue(prepared)
        XCTAssertNil(model.authorization)
        XCTAssertEqual(model.error, SecureFailure.pending.localizedDescription)
        XCTAssertFalse(model.busy)
    }

    func testMarkdownUsesNativeBlockAndInlineParsing() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".md")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("# Heading\n\n**Strong** [Link](https://example.com)\n\n- First\n- Second\n\n```swift\nlet x = 1\n```".utf8).write(to: url)
        let document = try SecureMarkdownDocument(url: url, name: "example.md")
        XCTAssertTrue(document.blocks.contains { $0.heading == 1 })
        XCTAssertEqual(document.blocks.filter { $0.prefix != nil }.count, 2)
        XCTAssertTrue(document.blocks.contains { $0.code })
        XCTAssertTrue(document.blocks.contains { block in block.text.runs.contains { $0.link?.host == "example.com" } })
    }
}
