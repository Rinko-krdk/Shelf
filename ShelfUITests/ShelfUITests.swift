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
        let stack = app.descendants(matching: .any)["shelf-file-stack"]
        XCTAssertTrue(stack.waitForExistence(timeout: 2))
        let window = app.windows["shelf-panel"]
        let originalOrigin = window.frame.origin
        let moveFrame = app.descendants(matching: .any)["shelf-window-move-handle"]
        XCTAssertTrue(moveFrame.exists)
        let dragStart = moveFrame.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let dragEnd = window.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
        dragStart.press(forDuration: 0.2, thenDragTo: dragEnd)
        XCTAssertNotEqual(window.frame.origin, originalOrigin)
        app.descendants(matching: .any)["shelf-content-panel"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .hover()
        XCTAssertTrue(app.buttons["shelf-clear-button"].exists)
        XCTAssertTrue(app.buttons["shelf-hide-button"].exists)
        XCTAssertFalse(app.buttons["copy-selected-items"].exists)
        XCTAssertFalse(app.buttons["move-selected-items"].exists)

        statusItem.click()
        XCTAssertTrue(app.menuItems["隐藏 Shelf"].waitForExistence(timeout: 2))
        app.menuItems["隐藏 Shelf"].click()
        XCTAssertFalse(app.windows["shelf-panel"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testPerFileSelectionAndOverflowExpansion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--shelf-ui-test-fixture"]
        app.launch()

        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["显示 Shelf"].click()

        let window = app.windows["shelf-panel"]
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        let overflow = app.buttons["shelf-overflow-toggle"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 2))
        XCTAssertEqual(overflow.label, "展开剩余 2 个文件")
        let originalHeight = window.frame.height
        overflow.click()

        let rowID = "shelf-expanded-file-row-00000000-0000-0000-0000-000000000004"
        let row = app.descendants(matching: .any)[rowID]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        row.click()
        XCTAssertEqual(row.value as? String, "已选中")
        XCTAssertGreaterThan(window.frame.height, originalHeight)

        app.buttons["shelf-overflow-toggle"].click()
        XCTAssertFalse(row.waitForExistence(timeout: 1))
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
