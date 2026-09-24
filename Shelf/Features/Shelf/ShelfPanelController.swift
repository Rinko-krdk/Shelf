//
//  ShelfPanelController.swift
//  Shelf
//

import AppKit
import SwiftUI

@MainActor
final class ShelfPanelController: NSObject, NSWindowDelegate {
    private let panel: ShelfPanel
    private var hasPositionedPanel = false

    private(set) var isVisible = false {
        didSet {
            guard oldValue != isVisible else { return }
            onVisibilityChanged?(isVisible)
        }
    }

    var onVisibilityChanged: ((Bool) -> Void)?

    init(viewModel: ShelfViewModel) {
        panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.delegate = self
        panel.onCancelOperation = { [weak self] in
            self?.hide()
        }
        panel.title = "Shelf"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.setAccessibilityIdentifier("shelf-panel")

        let hostingView = NSHostingView(rootView: ShelfView(viewModel: viewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = NSView()
        panel.contentView?.addSubview(hostingView)

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }

    func show() {
        if !hasPositionedPanel {
            panel.center()
            hasPositionedPanel = true
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }

    func hide() {
        panel.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}

private final class ShelfPanel: NSPanel {
    var onCancelOperation: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancelOperation?()
    }
}
