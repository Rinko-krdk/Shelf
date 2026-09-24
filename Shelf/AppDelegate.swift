//
//  AppDelegate.swift
//  Shelf
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var shelfPanelController: ShelfPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = ShelfPanelController()
        let menuBarController = MenuBarController(panelController: panelController)

        shelfPanelController = panelController
        self.menuBarController = menuBarController
    }

    func applicationWillTerminate(_ notification: Notification) {
        shelfPanelController?.hide()
        menuBarController?.tearDown()
    }
}
