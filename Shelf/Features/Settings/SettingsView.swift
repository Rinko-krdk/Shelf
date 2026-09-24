//
//  SettingsView.swift
//  Shelf
//

import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @ObservedObject var shortcutService: ShortcutService
    @State private var isRecording = false

    var body: some View {
        Form {
            Section("快捷键") {
                LabeledContent("呼出 / 隐藏 Shelf") {
                    Text(shortcutService.shortcut.displayName)
                        .monospaced()
                        .accessibilityIdentifier("current-shelf-shortcut")
                }

                HStack {
                    if isRecording {
                        KeyboardShortcutRecorder { keyCode, modifiers in
                            isRecording = false
                            _ = shortcutService.setShortcut(
                                ShelfShortcut(keyCode: keyCode, modifierFlags: modifiers)
                            )
                        } onCancel: {
                            isRecording = false
                        }
                        .frame(width: 1, height: 1)

                        Text("按下新的快捷键组合…")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("shortcut-recording-prompt")
                    }
                    Spacer()
                    Button(isRecording ? "取消录制" : "更改快捷键") {
                        isRecording.toggle()
                    }
                    .accessibilityIdentifier("record-shelf-shortcut-button")
                }

                if let lastError = shortcutService.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("shortcut-error-message")
                }
            }

            Section {
                Text("按下包含修饰键的组合。若系统无法注册，当前快捷键会继续生效。")
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

private struct KeyboardShortcutRecorder: NSViewRepresentable {
    let onRecord: (UInt16, UInt) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = onRecord
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ view: ShortcutRecorderNSView, context: Context) {
        view.onRecord = onRecord
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    }
}

private final class ShortcutRecorderNSView: NSView {
    var onRecord: ((UInt16, UInt) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }
        let supported: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let flags = event.modifierFlags.intersection(supported)
        guard !flags.isEmpty else { return }
        onRecord?(event.keyCode, flags.rawValue)
    }
}
