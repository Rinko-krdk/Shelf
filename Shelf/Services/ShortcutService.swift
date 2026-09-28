//
//  ShortcutService.swift
//  Shelf
//

import AppKit
import Carbon
import Combine
import Foundation

struct ShelfShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt

    static let `default` = ShelfShortcut(
        keyCode: UInt16(kVK_Space),
        modifierFlags: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    var displayName: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags).intersection(.deviceIndependentFlagsMask)
        var value = ""
        if flags.contains(.control) { value += "⌃" }
        if flags.contains(.option) { value += "⌥" }
        if flags.contains(.shift) { value += "⇧" }
        if flags.contains(.command) { value += "⌘" }
        return value + Self.keyName(for: keyCode)
    }

    private static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_Return): return "↩"
        case UInt16(kVK_Tab): return "⇥"
        case UInt16(kVK_Delete): return "⌫"
        case UInt16(kVK_Escape): return "Esc"
        default:
            let keyMap: [UInt16: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
                11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
                18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
                27: "-", 28: "8", 29: "0", 30: "]", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
                38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
                47: ".", 48: "Tab", 49: "Space", 50: "`", 65: ".", 67: "*", 69: "+", 71: "Clear",
                75: "/", 76: "↩", 78: "-", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4",
                87: "5", 88: "6", 89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7",
                99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12", 115: "Home",
                116: "Page Up", 117: "Forward Delete", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
                123: "←", 124: "→", 125: "↓", 126: "↑"
            ]
            return keyMap[keyCode] ?? "Key \(keyCode)"
        }
    }
}

enum ShortcutRegistrationError: LocalizedError {
    case modifiersRequired
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .modifiersRequired:
            return L10n.string("A shortcut must include at least one modifier key.")
        case let .registrationFailed(status):
            return L10n.string("Could not register this shortcut (system error %d). Another app may be using it.", status)
        }
    }
}

@MainActor
final class ShortcutService: ObservableObject {
    @Published private(set) var shortcut: ShelfShortcut
    @Published private(set) var lastError: String?

    var onShortcut: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    fileprivate var hotKeyIdentifier: UInt32 = 0
    private var nextIdentifier: UInt32 = 1
    private let defaults: UserDefaults
    private let shortcutDefaultsKey = "shelf.globalShortcut"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: shortcutDefaultsKey),
           let saved = try? JSONDecoder().decode(ShelfShortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .default
        }
    }

    @discardableResult
    func register() -> Bool {
        do {
            try installEventHandlerIfNeeded()
            try install(shortcut)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func setShortcut(_ newShortcut: ShelfShortcut) -> Bool {
        do {
            try validate(newShortcut)
            let previousShortcut = shortcut
            let previousIdentifier = hotKeyIdentifier
            let previousHotKey = hotKey

            if let previousHotKey {
                UnregisterEventHotKey(previousHotKey)
                hotKey = nil
            }

            do {
                try install(newShortcut)
            } catch {
                if previousHotKey != nil {
                    hotKey = nil
                    try? install(previousShortcut, identifier: previousIdentifier)
                }
                throw error
            }

            shortcut = newShortcut
            if let data = try? JSONEncoder().encode(newShortcut) {
                defaults.set(data, forKey: shortcutDefaultsKey)
            }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func validate(_ shortcut: ShelfShortcut) throws {
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifierFlags)
            .intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .control, .option, .shift]) else {
            throw ShortcutRegistrationError.modifiersRequired
        }
    }

    private func install(_ shortcut: ShelfShortcut, identifier: UInt32? = nil) throws {
        try validate(shortcut)
        let carbonModifiers = Self.carbonModifiers(from: shortcut.modifierFlags)
        let newIdentifier = identifier ?? nextIdentifier
        let hotKeyID = EventHotKeyID(signature: 0x53484C46, id: newIdentifier)
        var registeredHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &registeredHotKey
        )
        guard status == noErr, let registeredHotKey else {
            throw ShortcutRegistrationError.registrationFailed(status)
        }
        hotKey = registeredHotKey
        hotKeyIdentifier = newIdentifier
        nextIdentifier = max(nextIdentifier, newIdentifier &+ 1)
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            shelfHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard status == noErr else {
            throw ShortcutRegistrationError.registrationFailed(status)
        }
    }

    private static func carbonModifiers(from rawValue: UInt) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: rawValue)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

nonisolated private func shelfHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let service = Unmanaged<ShortcutService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        guard hotKeyID.id == service.hotKeyIdentifier else { return }
        service.onShortcut?()
    }
    return noErr
}
