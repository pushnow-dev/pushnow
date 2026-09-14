import XCTest

@MainActor
final class PhysicalInboxUITests: XCTestCase {
    func testWeatherRowAndDetail() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical-device acceptance only")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let row = app.buttons["inbox-item-v2:22fba9f4-5cae-4d91-907b-58cb7e8834dc"]
        guard row.waitForExistence(timeout: 30) else {
            throw XCTSkip("Requires the authorized weather acceptance account")
        }
        for label in ["加密来源", "已加密", "Encrypted source", "Encrypted"] {
            XCTAssertFalse(app.staticTexts[label].exists)
        }
        let inbox = XCTAttachment(screenshot: app.screenshot())
        inbox.name = "physical-inbox-content-icons"
        inbox.lifetime = .keepAlways
        add(inbox)
        row.tap()
        XCTAssertTrue(app.staticTexts["武汉今日天气｜9月13日"].waitForExistence(timeout: 20))
        let body = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "外出注意防晒")).firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 20))
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "physical-weather-detail"
        detail.lifetime = .keepAlways
        add(detail)
        #endif
    }
}

@MainActor
final class AccountFlowUITests: XCTestCase {
    private let app = XCUIApplication()
    private let email = "simulator-account@example.com"
    private let password = "Simulator-only-Password-42"

    override func setUp() {
        continueAfterFailure = false
        app.launchEnvironment["PUSHNOW_TEST_API_URL"] = "http://127.0.0.1:8799"
        app.launchArguments = ["-pushnow.language", "en", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        addUIInterruptionMonitor(withDescription: "Notifications") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            return false
        }
        app.launch()
    }

    func testAutomaticAccountSender() async throws {
        _ = try await request("/__qa/account-setup", body: ["email":email,"password":password])
        let signIn = app.buttons["Sign in with email"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 30))
        signIn.tap()
        fill("auth-email", email)
        fill("auth-password", password, secure: true)
        app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.buttons["home-settings"].waitForExistence(timeout: 30))
        app.tap()
        try await Task.sleep(for: .seconds(5))
        _ = try await request("/__qa/account-sender", body: ["email":email,"password":password])
        let result = try await request("/__qa/account-finish", body: [:])
        XCTAssertEqual(result["authorized"] as? Bool, true)
        XCTAssertEqual(result["devices"] as? Int, 1)
        screenshot("automatic-account-sender")
    }

    func test01RegistrationSenderKeysAndLogs() async throws {
        tap("Email Login")
        fill("auth-email", email)
        app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.textFields["auth-code"].waitForExistence(timeout: 15))
        let mail = try await request("/__qa/mail?email=\(email)")
        let text = try XCTUnwrap(mail["body"] as? String)
        let range = try XCTUnwrap(text.range(of: "[0-9]{6}", options: .regularExpression))
        fill("auth-code", String(text[range]))
        app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.secureTextFields["auth-new-password"].waitForExistence(timeout: 15))
        fill("auth-new-password", password, secure: true)
        fill("auth-confirm-password", password, secure: true)
        app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.buttons["home-settings"].waitForExistence(timeout: 30))
        app.tap()
        openAccount()
        tap("Devices & Encryption")
        XCTAssertFalse(app.buttons["Revoke device"].exists)
        screenshot("01-devices-light")
        tap("Senders")
        let root = app.staticTexts["account-fingerprint"].label
        XCTAssertEqual(root.count, 64)
        let sender = try await request("/__qa/sender")
        fill("sender-code", try XCTUnwrap(sender["code"] as? String))
        tap("Look up code")
        XCTAssertTrue(app.staticTexts["sender-fingerprint"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["sender-fingerprint"].label, sender["fingerprint"] as? String)
        app.switches["sender-confirm"].tap()
        app.swipeUp()
        app.buttons["sender-approve"].tap()
        XCTAssertTrue(app.staticTexts["Sender authorized"].waitForExistence(timeout: 20))
        _ = try await request("/__qa/finish", body: ["fingerprint":root])
        screenshot("02-sender-authorized")
        _ = try await request("/__qa/send", body: ["title":"Inbox-only verification", "device_ids":[], "file":true])
        _ = try await request("/__qa/send", body: ["title":"All-device verification"])
        let scheduled = ISO8601DateFormatter().string(from: Date().addingTimeInterval(120))
        _ = try await request("/__qa/send", body: ["title":"Scheduled verification", "scheduled_at":scheduled])
        app.swipeDown()
        tap("Sender keys")
        XCTAssertTrue(app.staticTexts["Simulator SDK"].waitForExistence(timeout: 15))
        screenshot("03-keys-light")
        tap("Edit expiry")
        tap("Never")
        tap("7 days")
        tap("Save")
        XCTAssertTrue(app.buttons["Create another key"].waitForExistence(timeout: 15))
        tap("Create another key")
        tap("Create key")
        XCTAssertTrue(app.staticTexts["Keep this key safe. It will only be shown once."].waitForExistence(timeout: 15))
        tap("Done")
        app.buttons["Notification logs"].firstMatch.tap()
        // The new Key has no sends; return and open the original Key's logs.
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(identifier: "Notification logs").allElementsBoundByIndex.last?.tap()
        XCTAssertTrue(app.staticTexts["Simulator SDK"].firstMatch.waitForExistence(timeout: 15))
        screenshot("04-notification-logs")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Simulator SDK")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Device deliveries"].waitForExistence(timeout: 10))
        screenshot("05-delivery-detail")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Inbox-only verification"].waitForExistence(timeout: 20))
        tap("Inbox-only verification")
        XCTAssertTrue(app.staticTexts["Private SDK message body"].waitForExistence(timeout: 10))
        screenshot("06-decrypted-message")
    }

    func test02SecondDeviceLogin() async throws {
        tap("Email Login")
        tap("Password")
        fill("auth-email", email)
        fill("auth-password", password, secure: true)
        app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.buttons["home-settings"].waitForExistence(timeout: 30))
        app.tap(); openAccount(); tap("Devices & Encryption")
        XCTAssertTrue(app.staticTexts["pairing-code-value"].waitForExistence(timeout: 15))
        let code = app.staticTexts["pairing-code-value"].label
        XCTAssertEqual(code.count, 19)
        _ = try await request("/__qa/state", body: ["pairing_code":code])
        screenshot("07-second-device-pairing")
    }

    func test03ApproveSecondDevice() async throws {
        openAccount(); tap("Devices & Encryption"); tap("Approve device")
        let state = try await request("/__qa/state")
        fill("device-pairing-code", try XCTUnwrap(state["pairing_code"] as? String))
        tap("Approve device")
        XCTAssertTrue(app.staticTexts["Account devices"].waitForExistence(timeout: 15))
        screenshot("08-paired-devices")
    }

    func test04SecondDeviceDecryptsHistory() {
        XCTAssertTrue(app.staticTexts["Inbox-only verification"].waitForExistence(timeout: 25))
        tap("Inbox-only verification")
        XCTAssertTrue(app.staticTexts["Private SDK message body"].waitForExistence(timeout: 15))
        screenshot("09-second-device-decryption")
    }

    private func openAccount() {
        XCTAssertTrue(app.buttons["home-settings"].waitForExistence(timeout: 20))
        app.buttons["home-settings"].tap(); tap("Account")
    }
    private func tap(_ title: String) {
        let button = app.buttons[title].firstMatch
        if !button.waitForExistence(timeout: 10) { app.swipeUp() }
        if button.exists { button.tap() }
        else { let text = app.staticTexts[title].firstMatch; XCTAssertTrue(text.waitForExistence(timeout: 10)); text.tap() }
    }
    private func fill(_ id: String, _ value: String, secure: Bool = false) {
        let field = secure ? app.secureTextFields[id] : app.textFields[id]
        XCTAssertTrue(field.waitForExistence(timeout: 15)); field.tap(); field.typeText(value)
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    private func request(_ path: String, body: [String:Any]? = nil) async throws -> [String:Any] {
        var request = URLRequest(url: URL(string:"http://127.0.0.1:8799\(path)")!)
        if let body { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject:body) }
        request.setValue("application/json", forHTTPHeaderField:"content-type")
        let (data,response) = try await URLSession.shared.data(for:request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode,200)
        return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
    }
}

@MainActor
final class ReviewScreenshotUITests: XCTestCase {
    func testCaptureReviewScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for language in ["en", "zh-Hans", "ja", "ko", "es", "de"] {
            app.launchArguments = ["-pushnow.language", language, "-AppleLanguages", "(\(language))", "-AppleLocale", language, "-pushnow.appearance", "light"]
            app.launch()
            XCTAssertTrue(app.buttons["home-settings"].waitForExistence(timeout: 30))
            let row = app.buttons["inbox-item-v2:22fba9f4-5cae-4d91-907b-58cb7e8834dc"]
            if row.waitForExistence(timeout: 20) {
                capture(app, "\(language)-01-inbox")
                row.tap()
                capture(app, "\(language)-02-detail")
                app.terminate()
                app.launch()
            } else {
                capture(app, "\(language)-01-inbox")
            }
            app.buttons["home-settings"].tap()
            let membershipLabels = ["Membership", "会员", "メンバーシップ", "멤버십", "Membresía", "Mitgliedschaft"]
            for label in membershipLabels {
                let button = app.buttons[label]
                if button.waitForExistence(timeout: 3) { button.tap(); break }
            }
            XCTAssertTrue(membershipLabels.contains { app.navigationBars[$0].exists })
            capture(app, "\(language)-03-membership")
            app.terminate()
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
