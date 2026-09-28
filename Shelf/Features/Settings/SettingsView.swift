//
//  SettingsView.swift
//  Shelf
//

import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @ObservedObject var shortcutService: ShortcutService
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var isRecording = false

    var body: some View {
        Form {
            Section(L10n.string("Language")) {
                Picker(L10n.string("App Language"), selection: Binding(
                    get: { languageManager.language },
                    set: { languageManager.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .accessibilityIdentifier("app-language-picker")
            }

            Section(L10n.string("Shortcut")) {
                LabeledContent {
                    Text(shortcutService.shortcut.displayName)
                        .monospaced()
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityIdentifier("current-shelf-shortcut")
                } label: {
                    Label(L10n.string("Show / Hide Shelf"), systemImage: "rectangle.inset.filled.and.person.filled")
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

                        Text(L10n.string("Press a new shortcut…"))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("shortcut-recording-prompt")
                    }
                    Spacer()
                    Button(isRecording ? L10n.string("Cancel Recording") : L10n.string("Change Shortcut")) {
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
                Label {
                    Text(L10n.string("Press a shortcut that includes a modifier key. If macOS cannot register it, your current shortcut will stay active."))
                } icon: {
                    Image(systemName: "info.circle")
                }
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .navigationTitle(L10n.string("Settings"))
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
