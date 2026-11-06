//
//  SettingsView.swift
//  Shelf
//

import SwiftUI
import AppKit
import Carbon
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var shortcutService: ShortcutService
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var loginItemService: LoginItemService
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var isRecording = false

    var body: some View {
        Form {
            Section(L10n.string("General")) {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle(L10n.string("Launch at Login"), isOn: Binding(
                        get: { loginItemService.isRegistered },
                        set: { enabled in Task { await loginItemService.setEnabled(enabled) } }
                    ))
                    .disabled(!loginItemService.canChange)
                    .accessibilityIdentifier("launch-at-login-toggle")
                    Text(L10n.string("Start Shelf in the menu bar when you log in."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if loginItemService.status == .requiresApproval {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("Requested. Waiting for system approval; login startup is not active yet."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("login-item-approval-message")
                        Button(L10n.string("Open Login Items Settings…")) { loginItemService.openSystemSettings() }
                            .accessibilityIdentifier("login-item-settings-button")
                    }
                } else if loginItemService.status == .notFound {
                    Text(L10n.string("macOS could not find the login item. Turn on the switch to try registering it."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("login-item-unavailable-message")
                }

                if let error = loginItemService.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("login-item-error-message")
                }

                VStack(alignment: .leading, spacing: 5) {
                    Toggle(L10n.string("Shake Mouse to Show Shelf"), isOn: $appPreferences.shakeToShowEnabled)
                        .accessibilityIdentifier("shake-to-show-toggle")
                    Text(L10n.string("Enable mouse-shake gestures while dragging files."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

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

            Section {
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
            } header: {
                Text(L10n.string("Shortcut"))
            } footer: {
                Label {
                    Text(L10n.string("Press a shortcut that includes a modifier key. If macOS cannot register it, your current shortcut will stay active."))
                } icon: {
                    Image(systemName: "info.circle")
                }
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L10n.string("About")) {
                LabeledContent("Shelf") {
                    Text(L10n.string("Version %@ (build %@)",
                                     Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
                                     Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("app-version")
                }
                // Refresh the native labeled row's accessibility text when switching language.
                .id(languageManager.language)
                Text(Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? "© 2026 Rinko")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("app-copyright")
                Link(L10n.string("Report an Issue…"), destination: URL(string: "https://github.com/Rinko-krdk/Shelf/issues")!)
                    .accessibilityIdentifier("report-issue-link")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 600)
        .navigationTitle(L10n.string("Settings"))
        .accessibilityIdentifier("shelf-settings")
        .onAppear { loginItemService.refresh() }
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
