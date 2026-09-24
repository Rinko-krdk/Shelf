//
//  AppDelegate.swift
//  Shelf
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var shelfPanelController: ShelfPanelController?
    private var viewModel: ShelfViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = ShelfViewModel()
        viewModel.load()

        let panelController = ShelfPanelController(viewModel: viewModel)
        let menuBarController = MenuBarController(panelController: panelController, viewModel: viewModel)

        shelfPanelController = panelController
        self.menuBarController = menuBarController
        self.viewModel = viewModel
    }

    func applicationWillTerminate(_ notification: Notification) {
        shelfPanelController?.hide()
        menuBarController?.tearDown()
    }
}
