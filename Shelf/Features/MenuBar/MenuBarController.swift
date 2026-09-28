//
//  MenuBarController.swift
//  Shelf
//

import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let panelController: ShelfPanelController
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let toggleItem: NSMenuItem
    private let clearItem: NSMenuItem
    private let viewModel: ShelfViewModel
    private let settingsWindowController: SettingsWindowController
    private var itemsCancellable: AnyCancellable?

    init(
        panelController: ShelfPanelController,
        viewModel: ShelfViewModel,
        settingsWindowController: SettingsWindowController
    ) {
        self.panelController = panelController
        self.viewModel = viewModel
        self.settingsWindowController = settingsWindowController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu(title: "Shelf")
        toggleItem = NSMenuItem(title: "显示 Shelf", action: nil, keyEquivalent: "")
        clearItem = NSMenuItem(title: "清空 Shelf", action: #selector(clearShelf(_:)), keyEquivalent: "")

        super.init()

        configureStatusItem()
        configureMenu()

        panelController.onVisibilityChanged = { [weak self] _ in
            self?.updateToggleItem()
        }
        itemsCancellable = viewModel.$items.sink { [weak self] _ in
            self?.updateClearItem()
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

        clearItem.target = self
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
        updateClearItem()
    }

    private func updateToggleItem() {
        toggleItem.title = panelController.isVisible ? "隐藏 Shelf" : "显示 Shelf"
    }

    private func updateClearItem() {
        clearItem.isEnabled = !viewModel.items.isEmpty
    }

    @objc private func toggleShelf(_ sender: Any?) {
        panelController.toggle()
        updateToggleItem()
    }

    @objc private func clearShelf(_ sender: Any?) {
        guard !viewModel.items.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "清空 Shelf？"
        alert.informativeText = "只会移除 Shelf 中的引用，不会删除原文件。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空 Shelf")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        viewModel.removeAll()
        panelController.hideIfEmptyImmediately()
    }

    @objc private func openSettings(_ sender: Any?) {
        settingsWindowController.showSettings()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}
