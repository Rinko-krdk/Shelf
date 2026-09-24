//
//  MenuBarController.swift
//  Shelf
//

import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let panelController: ShelfPanelController
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let toggleItem: NSMenuItem

    init(panelController: ShelfPanelController) {
        self.panelController = panelController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu(title: "Shelf")
        toggleItem = NSMenuItem(title: "显示 Shelf", action: nil, keyEquivalent: "")

        super.init()

        configureStatusItem()
        configureMenu()

        panelController.onVisibilityChanged = { [weak self] _ in
            self?.updateToggleItem()
        }
    }

    func tearDown() {
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "tray",
            accessibilityDescription: "Shelf"
        )
        button.image?.isTemplate = true
        button.toolTip = "Shelf"
        button.setAccessibilityLabel("Shelf")
        button.setAccessibilityIdentifier("shelf-status-item")
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        toggleItem.action = #selector(toggleShelf(_:))
        toggleItem.target = self
        toggleItem.identifier = NSUserInterfaceItemIdentifier("toggle-shelf")

        let clearItem = NSMenuItem(
            title: "清空 Shelf",
            action: #selector(clearShelf(_:)),
            keyEquivalent: ""
        )
        clearItem.target = self
        clearItem.isEnabled = false
        clearItem.identifier = NSUserInterfaceItemIdentifier("clear-shelf")

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.identifier = NSUserInterfaceItemIdentifier("open-settings")

        let quitItem = NSMenuItem(
            title: "退出 Shelf",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.identifier = NSUserInterfaceItemIdentifier("quit-shelf")

        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(clearItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        updateToggleItem()
    }

    private func updateToggleItem() {
        toggleItem.title = panelController.isVisible ? "隐藏 Shelf" : "显示 Shelf"
    }

    @objc private func toggleShelf(_ sender: Any?) {
        panelController.toggle()
        updateToggleItem()
    }

    @objc private func clearShelf(_ sender: Any?) {
        // Enabled once ShelfStore is introduced. Keeping this action inert protects
        // the current shell from accidentally touching user files.
    }

    @objc private func openSettings(_ sender: Any?) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: sender)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}
