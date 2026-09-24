//
//  SettingsView.swift
//  Shelf
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("快捷键") {
                LabeledContent("呼出 / 隐藏 Shelf") {
                    Text("尚未配置")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("快捷键设置将在后续版本中启用。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .navigationTitle("设置")
        .accessibilityIdentifier("shelf-settings")
    }
}
