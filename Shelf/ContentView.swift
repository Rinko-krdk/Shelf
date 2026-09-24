//
//  ContentView.swift
//  Shelf
//
//  Created by Rinko  on 2026/09/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Shelf", systemImage: "tray")
        } description: {
            Text("文件中转架将在后续阶段启用。")
        }
        .accessibilityIdentifier("shelf-empty-state")
    }
}
