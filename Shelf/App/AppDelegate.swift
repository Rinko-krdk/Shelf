//
//  AppDelegate.swift
//  Shelf
//

import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var shelfPanelController: ShelfPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var viewModel: ShelfViewModel?
    private var mouseShakeMonitor: MouseShakeMonitor?
    private var uiTestFixtureDirectory: URL?
    let shortcutService = ShortcutService()
    let appPreferences: AppPreferences
    let loginItemService: LoginItemService

    override init() {
        if ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-settings") {
            let environment = ProcessInfo.processInfo.environment
            let defaults = UserDefaults(suiteName: environment["SHELF_UI_TEST_PREFERENCES_SUITE"] ?? "Shelf.SettingsUITests")!
            appPreferences = AppPreferences(defaults: defaults)
            loginItemService = LoginItemService(client: SettingsFixtureLoginItemClient(statusName: environment["SHELF_UI_TEST_LOGIN_STATUS"]))
        } else {
            appPreferences = AppPreferences()
            loginItemService = LoginItemService()
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if ProcessInfo.processInfo.arguments.contains("--shelf-reset-language") {
            LanguageManager.shared.setLanguage(.english)
        }
        if ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-settings") {
            NSApp.appearance = NSAppearance(named: ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-dark-appearance") ? .darkAqua : .aqua)
        }

        let viewModel = ShelfViewModel()
        viewModel.removeAllForSessionBoundary()
        let usesWarningFixture = ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-warning-fixture")
        if ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-fixture") || usesWarningFixture {
            NSApp.appearance = NSAppearance(named: ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-dark-appearance") ? .darkAqua : .aqua)
            let fixtureDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ShelfUITest-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
                let items = try (0..<5).map { index -> ShelfItem in
                    let fileName = index == 0
                        ? "fixture-1-this-is-a-very-long-file-name-that-does-not-fit-in-a-list-row.txt"
                        : "fixture-\(index + 1).txt"
                    let url = fixtureDirectory.appendingPathComponent(fileName)
                    try Data("Shelf UI test fixture \(index + 1)".utf8).write(to: url)
                    let reference = ShelfFileService().makeItem(for: url)
                    var item = ShelfItem(
                        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                        bookmarkData: reference.bookmarkData,
                        bookmarkAllowsWriteAccess: reference.bookmarkAllowsWriteAccess,
                        fallbackURLString: url.absoluteString,
                        displayName: url.lastPathComponent,
                        contentTypeIdentifier: "public.plain-text",
                        status: reference.status,
                        resolvedURL: url
                    )
                    if usesWarningFixture {
                        if index == 0 { item.hasOpenFailure = true }
                        if index == 1 {
                            try FileManager.default.removeItem(at: url)
                            item.status = .missing
                        }
                    }
                    return item
                }
                viewModel.add(items: items)
                uiTestFixtureDirectory = fixtureDirectory
            } catch {
                try? FileManager.default.removeItem(at: fixtureDirectory)
            }
        }

        let panelController = ShelfPanelController(viewModel: viewModel)
        let settingsWindowController = SettingsWindowController(
            shortcutService: shortcutService,
            appPreferences: appPreferences,
            loginItemService: loginItemService
        )
        let menuBarController = MenuBarController(
            panelController: panelController,
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )

        let mouseShakeMonitor = MouseShakeMonitor()
        mouseShakeMonitor.onShake = { [weak panelController] in
            panelController?.summonByShake()
        }
        mouseShakeMonitor.bind(to: appPreferences)

        shortcutService.onShortcut = { [weak panelController] in panelController?.toggle() }
        if !shortcutService.register(), let message = shortcutService.lastError {
            let alert = NSAlert()
            alert.messageText = L10n.string("Global Shortcut Unavailable")
            alert.informativeText = "\(message)\n\n\(L10n.string("You can still show or hide Shelf from the menu bar, or change the shortcut in Settings."))"
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.string("OK"))
            alert.runModal()
        }

        shelfPanelController = panelController
        self.settingsWindowController = settingsWindowController
        self.menuBarController = menuBarController
        self.viewModel = viewModel
        self.mouseShakeMonitor = mouseShakeMonitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutService.unregister()
        mouseShakeMonitor?.stop()
        settingsWindowController?.close()
        shelfPanelController?.hide()
        menuBarController?.tearDown()
        if let uiTestFixtureDirectory {
            try? FileManager.default.removeItem(at: uiTestFixtureDirectory)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        viewModel?.refreshStatuses()
        loginItemService.refresh()
    }
}

/// Opt-in UI fixture: exercising settings must never register a real login item.
@MainActor
private final class SettingsFixtureLoginItemClient: LoginItemClient {
    var status: SMAppService.Status
    private let failsRegistration: Bool

    init(statusName: String?) {
        failsRegistration = statusName == "error"
        switch statusName {
        case "requiresApproval": status = .requiresApproval
        case "notFound": status = .notFound
        default: status = .notRegistered
        }
    }

    func register() throws {
        if failsRegistration { throw CocoaError(.fileWriteNoPermission) }
        status = .enabled
    }
    func unregister() async throws { status = .notRegistered }
    func openSystemSettings() {}
}
