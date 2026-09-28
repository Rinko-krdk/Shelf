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
    private var languageCancellable: AnyCancellable?

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
        toggleItem = NSMenuItem(title: L10n.string("Show Shelf"), action: nil, keyEquivalent: "")
        clearItem = NSMenuItem(title: L10n.string("Clear Shelf"), action: #selector(clearShelf(_:)), keyEquivalent: "")

        super.init()

        configureStatusItem()
        configureMenu()

        panelController.onVisibilityChanged = { [weak self] _ in
            self?.updateToggleItem()
        }
        itemsCancellable = viewModel.$items.sink { [weak self] _ in
            self?.updateClearItem()
        }
        languageCancellable = LanguageManager.shared.$language.sink { [weak self] _ in
            self?.updateLocalizedText()
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
        button.toolTip = L10n.string("Shelf")
        button.setAccessibilityLabel(L10n.string("Shelf"))
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
            title: L10n.string("Settings…"),
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.identifier = NSUserInterfaceItemIdentifier("open-settings")

        let quitItem = NSMenuItem(
            title: L10n.string("Quit Shelf"),
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

        updateLocalizedText()
    }

    private func updateLocalizedText() {
        menu.title = "Shelf"
        statusItem.button?.toolTip = L10n.string("Shelf")
        statusItem.button?.setAccessibilityLabel(L10n.string("Shelf"))
        clearItem.title = L10n.string("Clear Shelf")
        menu.items.first(where: { $0.identifier?.rawValue == "open-settings" })?.title = L10n.string("Settings…")
        menu.items.first(where: { $0.identifier?.rawValue == "quit-shelf" })?.title = L10n.string("Quit Shelf")
        updateToggleItem()
        updateClearItem()
    }

    private func updateToggleItem() {
        toggleItem.title = panelController.isVisible ? L10n.string("Hide Shelf") : L10n.string("Show Shelf")
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
        alert.messageText = L10n.string("Clear Shelf?")
        alert.informativeText = L10n.string("This removes references from Shelf only. Original files will not be deleted.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("Clear Shelf"))
        alert.addButton(withTitle: L10n.string("Cancel"))
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
