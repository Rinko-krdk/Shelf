//
//  ShelfPanelController.swift
//  Shelf
//

import AppKit
import SwiftUI

enum ShelfPresentationState: Equatable {
    case hidden
    case peek
    case expanded
}

@MainActor
final class ShelfPanelController: NSObject, NSWindowDelegate {
    private let panel: ShelfPanel
    private let viewModel: ShelfViewModel
    private var edgeDropPanel: ShelfEdgeDropPanel?
    private var screenParametersObserver: NSObjectProtocol?
    private let normalSize = NSSize(width: 420, height: 280)
    private let edgeDropWidth: CGFloat = 12
    private var isDragPresented = false

    private(set) var presentationState: ShelfPresentationState = .hidden

    var isVisible: Bool { presentationState != .hidden }

    var onVisibilityChanged: ((Bool) -> Void)?

    init(viewModel: ShelfViewModel) {
        self.viewModel = viewModel
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
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.setAccessibilityIdentifier("shelf-panel")
        panel.setFrame(NSRect(origin: .zero, size: normalSize), display: false)

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

        let edgeDropPanel = ShelfEdgeDropPanel(contentRect: .zero)
        edgeDropPanel.onDragEntered = { [weak self] in
            self?.beginExternalDrag()
        }
        edgeDropPanel.onDragUpdated = { [weak self] location in
            self?.updateExternalDrag(at: location)
        }
        edgeDropPanel.onDragExited = { [weak self] in
            self?.endExternalDrag()
        }
        edgeDropPanel.onDragEnded = { [weak self] in
            self?.endExternalDrag()
        }
        edgeDropPanel.onPerformDrop = { [weak self] pasteboard in
            self?.performExternalDrop(from: pasteboard) ?? false
        }
        self.edgeDropPanel = edgeDropPanel
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateWindowFrames() }
        }
        updateWindowFrames()
        edgeDropPanel.orderFront(nil)
    }

    func show() {
        viewModel.refreshStatuses()
        isDragPresented = false
        transition(to: .expanded, animated: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        isDragPresented = false
        transition(to: .hidden, animated: true)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private func beginExternalDrag() {
        guard presentationState == .hidden else { return }
        isDragPresented = true
        edgeDropPanel?.showsPeek = true
        transition(to: .peek, animated: true)
    }

    private func updateExternalDrag(at location: NSPoint) {
        guard isDragPresented, presentationState == .peek else { return }
        let screen = NSScreen.main?.visibleFrame ?? .zero
        if location.x < screen.maxX - normalSize.width * 0.55 {
            transition(to: .expanded, animated: true)
        }
    }

    private func endExternalDrag() {
        guard isDragPresented else { return }
        isDragPresented = false
        edgeDropPanel?.showsPeek = false
        transition(to: .hidden, animated: true)
    }

    private func performExternalDrop(from pasteboard: NSPasteboard) -> Bool {
        let urls = ShelfDropImporter.loadFileURLs(from: pasteboard)
        guard !urls.isEmpty else {
            endExternalDrag()
            return false
        }

        viewModel.add(urls: urls)
        isDragPresented = false
        edgeDropPanel?.showsPeek = false
        transition(to: .expanded, animated: false)
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    private func transition(to state: ShelfPresentationState, animated: Bool) {
        let oldVisibility = isVisible
        presentationState = state
        updateWindowFrames(animated: animated)
        if state == .hidden {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
        if isDragPresented {
            edgeDropPanel?.orderFront(nil)
        }
        if oldVisibility != isVisible {
            onVisibilityChanged?(isVisible)
        }
    }

    private func updateWindowFrames(animated: Bool = false) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let width: CGFloat
        switch presentationState {
        case .hidden:
            width = edgeDropWidth
        case .peek, .expanded:
            width = normalSize.width
        }

        let height = normalSize.height
        let frame = NSRect(
            x: screen.maxX - width,
            y: screen.maxY - height,
            width: width,
            height: height
        )
        let changes = {
            self.panel.setFrame(frame, display: true)
            self.edgeDropPanel?.setFrame(self.edgeFrame(for: screen), display: true)
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(frame, display: true)
            }
            self.edgeDropPanel?.setFrame(self.edgeFrame(for: screen), display: true)
        } else {
            changes()
        }
    }

    private func updateWindowFrames() {
        updateWindowFrames(animated: false)
    }

    private func edgeFrame(for screen: NSRect) -> NSRect {
        let width = isDragPresented && presentationState != .hidden
            ? normalSize.width
            : edgeDropWidth
        return NSRect(
            x: screen.maxX - width,
            y: screen.maxY - normalSize.height,
            width: width,
            height: normalSize.height
        )
    }

    deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
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

private final class ShelfEdgeDropPanel: NSPanel {
    var onDragEntered: (() -> Void)?
    var onDragUpdated: ((NSPoint) -> Void)?
    var onDragExited: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onPerformDrop: ((NSPasteboard) -> Bool)?
    var showsPeek = false {
        didSet { (contentView as? ShelfEdgeDropView)?.needsDisplay = true }
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        let dropView = ShelfEdgeDropView(frame: contentRect)
        dropView.panel = self
        dropView.edgePanel = self
        contentView = dropView
        dropView.registerForDraggedTypes([.fileURL, .URL])
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ShelfEdgeDropView: NSView {
    weak var panel: ShelfEdgeDropPanel?
    weak var edgePanel: ShelfEdgeDropPanel?

    override func draw(_ dirtyRect: NSRect) {
        guard edgePanel?.showsPeek == true else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 8), xRadius: 4, yRadius: 4).fill()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        panel?.onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        panel?.onDragUpdated?(sender.draggingLocation)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        panel?.onDragExited?()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        panel?.onDragEnded?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        panel?.onPerformDrop?(sender.draggingPasteboard) ?? false
    }
}
