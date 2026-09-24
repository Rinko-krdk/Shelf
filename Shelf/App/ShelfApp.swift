//
//  ShelfApp.swift
//  Shelf
//

import SwiftUI

@main
@MainActor
struct ShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
