//
//  ShelfApp.swift
//  Shelf
//
//  Created by Rinko  on 2026/09/24.
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
