import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testSettingsControlsAndShakePersistence() throws {
        let app = settingsApp()
        app.launch()
        defer { app.terminate() }
        let window = openSettings(app)
        let login = app.descendants(matching: .any)["launch-at-login-toggle"]
        XCTAssertTrue(login.waitForExistence(timeout: 2))
        XCTAssertEqual(toggleValue(login), 0)
        login.click()
        waitForValue("1", on: login)
        login.click()
        waitForValue("0", on: login)

        let shake = app.descendants(matching: .any)["shake-to-show-toggle"]
        XCTAssertEqual(toggleValue(shake), 1)
        shake.click()
        waitForValue("0", on: shake)

        app.buttons["record-shelf-shortcut-button"].click()
        XCTAssertTrue(app.staticTexts["shortcut-recording-prompt"].waitForExistence(timeout: 2))
        app.typeKey("a", modifierFlags: [])
        XCTAssertTrue(app.staticTexts["shortcut-recording-prompt"].exists)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.staticTexts["shortcut-recording-prompt"].exists)
        XCTAssertEqual(text(app.staticTexts["current-shelf-shortcut"]), "⌃⌥Space")

        window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -400)
        let copyright = app.staticTexts["app-copyright"]
        XCTAssertTrue(copyright.waitForExistence(timeout: 2))
        XCTAssertTrue(copyright.isHittable)
        XCTAssertEqual(text(copyright), "© 2026 Rinko")
        XCTAssertEqual(text(app.staticTexts["app-version"]), "Version 1.0 (build 3)")
        XCTAssertTrue(app.descendants(matching: .any)["report-issue-link"].exists)
        attachScreenshot(app, name: "Settings light English about")

        app.terminate()
        app.launch()
        _ = openSettings(app)
        let restoredShake = app.descendants(matching: .any)["shake-to-show-toggle"]
        XCTAssertTrue(restoredShake.waitForExistence(timeout: 2))
        XCTAssertEqual(toggleValue(restoredShake), 0)
        restoredShake.click()
        waitForValue("1", on: restoredShake)
    }

    @MainActor
    func testPendingApprovalInChineseDarkSettingsCanBeCancelled() throws {
        let app = settingsApp(status: "requiresApproval", dark: true)
        app.launch()
        defer { app.terminate() }
        _ = openSettings(app)
        app.descendants(matching: .any)["app-language-picker"].click()
        app.menuItems["简体中文"].click()
        let window = app.windows["设置"]
        XCTAssertTrue(window.waitForExistence(timeout: 2))
        let message = app.staticTexts["login-item-approval-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 2))
        XCTAssertTrue(text(message).contains("尚未生效"))
        XCTAssertTrue(app.buttons["login-item-settings-button"].exists)
        let login = app.descendants(matching: .any)["launch-at-login-toggle"]
        XCTAssertEqual(toggleValue(login), 1)
        attachScreenshot(app, name: "Settings dark Chinese approval")
        login.click()
        waitForValue("0", on: login)
        XCTAssertFalse(message.exists)
        window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -400)
        XCTAssertEqual(text(app.staticTexts["app-version"]), "版本 1.0（构建 3）")
        XCTAssertEqual(text(app.staticTexts["app-copyright"]), "© 2026 Rinko")
        XCTAssertTrue(app.staticTexts["app-copyright"].isHittable)
        attachScreenshot(app, name: "Settings dark Chinese about")
    }

    @MainActor
    func testMissingLoginStartupCanBeRegistered() throws {
        let app = settingsApp(status: "notFound")
        app.launch()
        defer { app.terminate() }
        _ = openSettings(app)
        XCTAssertTrue(app.staticTexts["login-item-unavailable-message"].waitForExistence(timeout: 2))
        let login = app.descendants(matching: .any)["launch-at-login-toggle"]
        XCTAssertTrue(login.isEnabled)
        login.click()
        waitForValue("1", on: login)
        XCTAssertFalse(app.staticTexts["login-item-unavailable-message"].exists)
    }

    @MainActor
    func testLoginStartupFailureShowsInlineErrorAndActualState() throws {
        let app = settingsApp(status: "error")
        app.launch()
        defer { app.terminate() }
        _ = openSettings(app)
        let login = app.descendants(matching: .any)["launch-at-login-toggle"]
        XCTAssertTrue(login.waitForExistence(timeout: 2))
        login.click()
        XCTAssertTrue(app.descendants(matching: .any)["login-item-error-message"].waitForExistence(timeout: 2))
        waitForValue("0", on: login)
        XCTAssertTrue(login.isEnabled)
        XCTAssertEqual(app.alerts.count, 0)
    }

    @MainActor
    private func settingsApp(status: String = "notRegistered", dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--shelf-ui-test-settings", "--shelf-reset-language"]
        if dark { app.launchArguments.append("--shelf-ui-test-dark-appearance") }
        app.launchEnvironment["SHELF_UI_TEST_PREFERENCES_SUITE"] = "Shelf.SettingsUITests.\(UUID().uuidString)"
        app.launchEnvironment["SHELF_UI_TEST_LOGIN_STATUS"] = status
        return app
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) -> XCUIElement {
        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        let settings = app.menuItems["open-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.click()
        let window = app.windows["Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        return window
    }

    @MainActor
    private func waitForValue(_ value: String, on element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ OR value == %@", value, NSNumber(value: Int(value)!)), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    @MainActor
    private func toggleValue(_ element: XCUIElement) -> Int? {
        if let number = element.value as? NSNumber { return number.intValue }
        return (element.value as? String).flatMap(Int.init)
    }

    @MainActor
    private func text(_ element: XCUIElement) -> String {
        // Use static text's label; switch controls expose their state as a numeric value.
        element.label.isEmpty ? element.value as? String ?? "" : element.label
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
