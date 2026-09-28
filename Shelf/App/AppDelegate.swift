//
//  AppDelegate.swift
//  Shelf
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var shelfPanelController: ShelfPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var viewModel: ShelfViewModel?
    private var mouseShakeMonitor: MouseShakeMonitor?
    private var uiTestFixtureDirectory: URL?
    let shortcutService = ShortcutService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = ShelfViewModel()
        viewModel.removeAllForSessionBoundary()
        if ProcessInfo.processInfo.arguments.contains("--shelf-ui-test-fixture") {
            let fixtureDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ShelfUITest-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
                let items = try (0..<5).map { index -> ShelfItem in
                    let url = fixtureDirectory.appendingPathComponent("fixture-\(index + 1).txt")
                    try Data("Shelf UI test fixture \(index + 1)".utf8).write(to: url)
                    return ShelfItem(
                        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                        fallbackURLString: url.absoluteString,
                        displayName: url.lastPathComponent,
                        contentTypeIdentifier: "public.plain-text",
                        status: .available,
                        resolvedURL: url
                    )
                }
                viewModel.add(items: items)
                uiTestFixtureDirectory = fixtureDirectory
            } catch {
                try? FileManager.default.removeItem(at: fixtureDirectory)
            }
        }

        let panelController = ShelfPanelController(viewModel: viewModel)
        let settingsWindowController = SettingsWindowController(shortcutService: shortcutService)
        let menuBarController = MenuBarController(
            panelController: panelController,
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )

        let mouseShakeMonitor = MouseShakeMonitor()
        mouseShakeMonitor.onShake = { [weak panelController] in
            panelController?.summonByShake()
        }
        mouseShakeMonitor.start()

        shortcutService.onShortcut = { [weak panelController] in panelController?.toggle() }
        if !shortcutService.register(), let message = shortcutService.lastError {
            let alert = NSAlert()
            alert.messageText = "全局快捷键不可用"
            alert.informativeText = "\(message)\n\n仍可通过菜单栏图标显示或隐藏 Shelf，也可以在设置中更改快捷键。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好")
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
    }
}
