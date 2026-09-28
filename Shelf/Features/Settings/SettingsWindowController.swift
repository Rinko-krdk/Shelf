//
//  SettingsWindowController.swift
//  Shelf
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class SettingsWindowController: NSWindowController {
    private var hasPositionedWindow = false
    private var languageCancellable: AnyCancellable?

    init(shortcutService: ShortcutService) {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = L10n.string("Settings")
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.identifier = NSUserInterfaceItemIdentifier("shelf-settings-window")
        settingsWindow.contentView = NSHostingView(
            rootView: SettingsView(shortcutService: shortcutService)
        )
        super.init(window: settingsWindow)
        languageCancellable = LanguageManager.shared.$language.sink { [weak self] _ in
            self?.window?.title = L10n.string("Settings")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showSettings() {
        guard let window else { return }
        if !hasPositionedWindow {
            window.center()
            hasPositionedWindow = true
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
