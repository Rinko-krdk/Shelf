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
        app.launchArguments = ["--shelf-reset-language"]
        app.launch()

        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        statusItem.click()
        XCTAssertTrue(app.menuItems["Show Shelf"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["Clear Shelf"].exists)
        XCTAssertFalse(app.menuItems["Clear Shelf"].isEnabled)

        app.menuItems["Show Shelf"].click()
        XCTAssertTrue(app.dialogs["shelf-panel"].waitForExistence(timeout: 3))
        let window = app.dialogs["shelf-panel"]
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).hover()
        XCTAssertTrue(app.descendants(matching: .any)["shelf-content-panel"].waitForExistence(timeout: 2))
        app.descendants(matching: .any)["shelf-content-panel"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .hover()
        XCTAssertFalse(app.buttons["shelf-select-all-button"].isEnabled)
        XCTAssertTrue(app.buttons["shelf-clear-button"].exists)
        XCTAssertTrue(app.buttons["shelf-hide-button"].exists)
        XCTAssertFalse(app.buttons["copy-selected-items"].exists)
        XCTAssertFalse(app.buttons["move-selected-items"].exists)

        app.buttons["shelf-hide-button"].click()
        XCTAssertFalse(app.dialogs["shelf-panel"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testPerFileSelectionAndOverflowExpansion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--shelf-ui-test-fixture", "--shelf-reset-language"]
        app.launch()

        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["Show Shelf"].click()

        let window = app.dialogs["shelf-panel"]
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        let overflow = app.buttons["shelf-overflow-toggle"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 2))
        XCTAssertEqual(overflow.label, "Show 2 more files")

        let content = app.descendants(matching: .any)["shelf-content-panel"]
        content.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        let clearButton = app.buttons["shelf-clear-button"]
        let hideButton = app.buttons["shelf-hide-button"]
        let selectAllButton = app.buttons["shelf-select-all-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
        XCTAssertTrue(hideButton.exists)
        XCTAssertTrue(selectAllButton.exists)
        XCTAssertTrue(selectAllButton.isEnabled)
        XCTAssertFalse(clearButton.frame.intersects(overflow.frame), "Clear: \(clearButton.frame), overflow: \(overflow.frame)")
        XCTAssertFalse(hideButton.frame.intersects(overflow.frame))
        XCTAssertFalse(selectAllButton.frame.intersects(overflow.frame))

        selectAllButton.click()
        XCTAssertEqual(selectAllButton.label, "Deselect All")
        selectAllButton.click()
        XCTAssertEqual(selectAllButton.label, "Select All")
        app.descendants(matching: .any)["shelf-stack-item-00000000-0000-0000-0000-000000000001"].click()
        XCTAssertEqual(selectAllButton.label, "Select All")
        selectAllButton.click()
        XCTAssertEqual(selectAllButton.label, "Deselect All")

        let originalHeight = window.frame.height
        overflow.click()

        let rowID = "shelf-expanded-file-row-00000000-0000-0000-0000-000000000004"
        let row = app.descendants(matching: .any)[rowID]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        let firstRow = app.descendants(matching: .any)["shelf-expanded-file-row-00000000-0000-0000-0000-000000000001"]
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        let filenameTooltip = app.staticTexts["shelf-filename-tooltip"]
        XCTAssertTrue(filenameTooltip.waitForExistence(timeout: 2))
        XCTAssertEqual(filenameTooltip.value as? String ?? filenameTooltip.label, "fixture-1-this-is-a-very-long-file-name-that-does-not-fit-in-a-list-row.txt")
        XCTAssertGreaterThanOrEqual(filenameTooltip.frame.minY, firstRow.frame.maxY)

        let middleRow = app.descendants(matching: .any)["shelf-expanded-file-row-00000000-0000-0000-0000-000000000003"]
        middleRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        let middleTooltipExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", "fixture-3.txt", "fixture-3.txt"),
            object: filenameTooltip
        )
        XCTAssertEqual(XCTWaiter.wait(for: [middleTooltipExpectation], timeout: 2), .completed)
        XCTAssertLessThanOrEqual(filenameTooltip.frame.maxY, middleRow.frame.minY)
        row.click()
        XCTAssertEqual(row.value as? String, "Selected")
        XCTAssertGreaterThan(window.frame.height, originalHeight)

        for index in 1...5 {
            let identifier = String(format: "shelf-expanded-file-row-00000000-0000-0000-0000-%012d", index)
            XCTAssertEqual(app.descendants(matching: .any)[identifier].value as? String, "Selected")
        }

        app.buttons["shelf-overflow-toggle"].click()
        XCTAssertFalse(row.waitForExistence(timeout: 1))
    }

    @MainActor
    func testFileWarningsInLightAppearance() throws {
        try checkFileWarnings(darkAppearance: false)
    }

    @MainActor
    func testFileWarningsInDarkAppearance() throws {
        try checkFileWarnings(darkAppearance: true)
    }

    @MainActor
    private func checkFileWarnings(darkAppearance: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--shelf-ui-test-warning-fixture", "--shelf-reset-language"]
        if darkAppearance { app.launchArguments.append("--shelf-ui-test-dark-appearance") }
        app.launch()
        defer { app.terminate() }
        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["Show Shelf"].click()
        XCTAssertTrue(app.dialogs["shelf-panel"].waitForExistence(timeout: 3))

        let firstStackItem = app.descendants(matching: .any)["shelf-stack-item-00000000-0000-0000-0000-000000000001"]
        firstStackItem.click()
        XCTAssertEqual(firstStackItem.value as? String, "Selected")
        let compactScreenshot = XCTAttachment(screenshot: app.screenshot())
        compactScreenshot.name = "Compact file warning"
        compactScreenshot.lifetime = .keepAlways
        add(compactScreenshot)

        app.buttons["shelf-overflow-toggle"].click()
        let firstRow = app.descendants(matching: .any)["shelf-expanded-file-row-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 2))
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        let tooltip = app.staticTexts["shelf-filename-tooltip"]
        XCTAssertTrue(tooltip.waitForExistence(timeout: 2))
        XCTAssertTrue((tooltip.value as? String ?? tooltip.label).contains("Could not open"))
        XCTAssertFalse((tooltip.value as? String ?? tooltip.label).contains("could not be moved"))

        let missingRow = app.descendants(matching: .any)["shelf-expanded-file-row-00000000-0000-0000-0000-000000000002"]
        let missingRowCenter = missingRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Move the pointer first so the previous row's long tooltip no longer covers this row.
        missingRowCenter.hover()
        let missingReason = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "File not found", "File not found"),
            object: tooltip
        )
        XCTAssertEqual(XCTWaiter.wait(for: [missingReason], timeout: 2), .completed)
        missingRowCenter.click()
        XCTAssertEqual(missingRow.value as? String, "Selected")
        missingRowCenter.doubleClick()
        XCTAssertEqual(app.alerts.count, 0)
        let expandedScreenshot = XCTAttachment(screenshot: app.screenshot())
        expandedScreenshot.name = "Expanded file warning and reason"
        expandedScreenshot.lifetime = .keepAlways
        add(expandedScreenshot)
    }

    @MainActor
    func testSettingsMenuItemOpensSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--shelf-reset-language"]
        app.launch()

        let statusItem = app.menuBars.statusItems["Shelf"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()

        let settingsItem = app.menuItems["open-settings"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 2))
        settingsItem.click()

        XCTAssertTrue(app.windows["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["current-shelf-shortcut"].waitForExistence(timeout: 2))
        let shortcut = app.staticTexts["current-shelf-shortcut"]
        XCTAssertEqual(shortcut.value as? String ?? shortcut.label, "⌃⌥Space", shortcut.debugDescription)
        XCTAssertTrue(app.buttons["record-shelf-shortcut-button"].exists)
    }

    @MainActor
    func testLanguageCanBeChangedAndPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--shelf-reset-language"]
        app.launch()
        app.menuBars.statusItems["Shelf"].click()
        app.menuItems["open-settings"].click()

        let languagePicker = app.descendants(matching: .any)["app-language-picker"]
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 2))
        languagePicker.click()
        app.menuItems["简体中文"].click()
        XCTAssertTrue(app.windows["设置"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = []
        app.launch()
        app.menuBars.statusItems["Shelf"].click()
        XCTAssertTrue(app.menuItems["显示 Shelf"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--shelf-reset-language"]
        app.launch()
        app.terminate()
    }
}
