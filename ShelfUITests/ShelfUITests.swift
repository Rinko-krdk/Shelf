//
//  ShelfUITests.swift
//  ShelfUITests
//
//  Created by Rinko  on 2026/09/24.
//

import XCTest

final class ShelfUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testMenuBarMenuAndPanelVisibility() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        statusItem.click()
        XCTAssertTrue(app.menuItems["显示 Shelf"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["清空 Shelf"].exists)
        XCTAssertFalse(app.menuItems["清空 Shelf"].isEnabled)

        app.menuItems["显示 Shelf"].click()
        XCTAssertTrue(app.windows["shelf-panel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["shelf-empty-state"].waitForExistence(timeout: 2))

        statusItem.click()
        XCTAssertTrue(app.menuItems["隐藏 Shelf"].waitForExistence(timeout: 2))
        app.menuItems["隐藏 Shelf"].click()
        XCTAssertFalse(app.windows["shelf-panel"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testSettingsMenuItemOpensSettings() throws {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let settingsItem = app.menuItems["设置…"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 2))
        settingsItem.click()

        XCTAssertTrue(app.windows["设置"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["current-shelf-shortcut"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["current-shelf-shortcut"].label, "⌃⌥Space")
        XCTAssertTrue(app.buttons["record-shelf-shortcut-button"].exists)
    }
}
