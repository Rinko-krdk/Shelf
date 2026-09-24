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
    let shortcutService = ShortcutService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = ShelfViewModel()
        viewModel.load()

        let panelController = ShelfPanelController(viewModel: viewModel)
        let settingsWindowController = SettingsWindowController(shortcutService: shortcutService)
        let menuBarController = MenuBarController(
            panelController: panelController,
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutService.unregister()
        settingsWindowController?.close()
        shelfPanelController?.hide()
        menuBarController?.tearDown()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        viewModel?.refreshStatuses()
    }
}
