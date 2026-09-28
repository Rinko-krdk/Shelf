//
//  ShelfPanelController.swift
//  Shelf
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class ShelfPanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false

    private let panel: ShelfPanel
    private let viewModel: ShelfViewModel
    private let contentSize = NSSize(width: 148, height: 92)
    private let frameInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    private var overflowListHeight: CGFloat = 0
    private let expandedListSpacing: CGFloat = 13
    private var panelSize: NSSize {
        NSSize(
            width: contentSize.width + frameInsets.left + frameInsets.right,
            height: contentSize.height + frameInsets.top + frameInsets.bottom
                + (overflowListHeight > 0 ? expandedListSpacing + overflowListHeight : 0)
        )
    }
    private var presentationPoint = NSEvent.mouseLocation
    private var pendingEmptyDismissTask: Task<Void, Never>?
    private var screenParametersObserver: NSObjectProtocol?
    private var languageCancellable: AnyCancellable?

    var onVisibilityChanged: ((Bool) -> Void)?

    init(viewModel: ShelfViewModel) {
        self.viewModel = viewModel
        panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 168, height: 112)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.onCancelOperation = { [weak self] in self?.hide() }
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.setAccessibilityIdentifier("shelf-panel")

        let frameView = ShelfPanelFrameView(contentInsets: frameInsets)
        frameView.setAccessibilityElement(true)
        frameView.setAccessibilityLabel(L10n.string("Drag the frame to move Shelf"))
        frameView.setAccessibilityIdentifier("shelf-window-move-handle")
        frameView.onInteractionChanged = { [weak self] isInteracting in
            if isInteracting { self?.beginInteraction() }
            else { self?.endInteraction() }
        }
        panel.contentView = frameView
        languageCancellable = LanguageManager.shared.$language.sink { [weak frameView] _ in
            frameView?.setAccessibilityLabel(L10n.string("Drag the frame to move Shelf"))
        }

        let hostingView = NSHostingView(rootView: ShelfView(viewModel: viewModel, panelController: self))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        frameView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: frameInsets.left),
            hostingView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -frameInsets.right),
            hostingView.topAnchor.constraint(equalTo: frameView.topAnchor, constant: frameInsets.top),
            hostingView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor, constant: -frameInsets.bottom)
        ])

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.clampPanelToVisibleScreen() }
        }
    }

    func show() {
        pendingEmptyDismissTask?.cancel()
        viewModel.refreshStatuses()
        presentationPoint = NSEvent.mouseLocation
        showPanel(animated: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleEmptyDismiss(after: 3.5)
    }

    func summonByShake() {
        pendingEmptyDismissTask?.cancel()
        guard viewModel.items.isEmpty else {
            viewModel.removeAllForSessionBoundary()
            hidePanelImmediately()
            return
        }

        presentationPoint = NSEvent.mouseLocation
        showPanel(animated: true)
        scheduleEmptyDismiss(after: 3.5)
    }

    func hide() {
        pendingEmptyDismissTask?.cancel()
        viewModel.removeAllForSessionBoundary()
        hidePanelImmediately()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func endInteraction() {
        guard viewModel.items.isEmpty, isVisible else { return }
        scheduleEmptyDismiss(after: 1.2)
    }

    func beginInteraction() {
        pendingEmptyDismissTask?.cancel()
    }

    func hideIfEmptyImmediately() {
        guard viewModel.items.isEmpty else { return }
        hidePanelImmediately()
    }

    func setExpanded(_ expanded: Bool, listHeight: CGFloat) {
        let nextListHeight = expanded ? max(0, listHeight) : 0
        guard nextListHeight != overflowListHeight else { return }
        let previousTop = panel.frame.maxY
        overflowListHeight = nextListHeight
        let newSize = panelSize
        let origin = NSPoint(x: panel.frame.minX, y: previousTop - newSize.height)
        let target = NSRect(origin: origin, size: newSize)
        let bounded = clampedFrame(target)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(bounded, display: true)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private func showPanel(animated: Bool) {
        pendingEmptyDismissTask?.cancel()
        positionPanel()
        if animated {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        setVisible(true)
    }

    private func hidePanelImmediately() {
        pendingEmptyDismissTask?.cancel()
        panel.orderOut(nil)
        panel.alphaValue = 1
        setVisible(false)
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        onVisibilityChanged?(visible)
    }

    private func scheduleEmptyDismiss(after delay: TimeInterval) {
        pendingEmptyDismissTask?.cancel()
        pendingEmptyDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  viewModel.items.isEmpty else { return }
            hidePanelImmediately()
        }
    }

    private func positionPanel() {
        guard let screen = screen(at: presentationPoint) else { return }
        let margin: CGFloat = 14
        let belowY = presentationPoint.y - panelSize.height - margin
        let aboveY = presentationPoint.y + margin
        let candidateY = belowY >= screen.visibleFrame.minY ? belowY : aboveY
        let x = min(max(presentationPoint.x - panelSize.width / 2, screen.visibleFrame.minX), screen.visibleFrame.maxX - panelSize.width)
        let y = min(max(candidateY, screen.visibleFrame.minY), screen.visibleFrame.maxY - panelSize.height)
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    private func clampPanelToVisibleScreen() {
        guard isVisible else { return }
        panel.setFrame(clampedFrame(panel.frame), display: true)
    }

    private func clampedFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main else { return frame }
        let maxX = max(screen.visibleFrame.minX, screen.visibleFrame.maxX - frame.width)
        let maxY = max(screen.visibleFrame.minY, screen.visibleFrame.maxY - frame.height)
        let origin = NSPoint(
            x: min(max(frame.minX, screen.visibleFrame.minX), maxX),
            y: min(max(frame.minY, screen.visibleFrame.minY), maxY)
        )
        return NSRect(origin: origin, size: frame.size)
    }

    private func screen(at point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
    }

    deinit {
        if let screenParametersObserver { NotificationCenter.default.removeObserver(screenParametersObserver) }
    }
}

private final class ShelfPanel: NSPanel {
    var onCancelOperation: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onCancelOperation?() }
}

private final class ShelfPanelFrameView: NSView {
    private let contentInsets: NSEdgeInsets
    private var lastMouseLocation: NSPoint?
    private var isMovingPanel = false
    private var pushedDragCursor = false

    var onInteractionChanged: ((Bool) -> Void)?

    init(contentInsets: NSEdgeInsets) {
        self.contentInsets = contentInsets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }
        let innerFrame = NSRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.bottom,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: bounds.height - contentInsets.top - contentInsets.bottom
        )
        if innerFrame.contains(localPoint) {
            return super.hitTest(point)
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        isMovingPanel = true
        lastMouseLocation = NSEvent.mouseLocation
        onInteractionChanged?(true)
        NSCursor.closedHand.push()
        pushedDragCursor = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isMovingPanel,
              let lastMouseLocation,
              let window else { return }
        let currentMouseLocation = NSEvent.mouseLocation
        let delta = NSPoint(
            x: currentMouseLocation.x - lastMouseLocation.x,
            y: currentMouseLocation.y - lastMouseLocation.y
        )
        move(window, by: delta)
        self.lastMouseLocation = currentMouseLocation
    }

    override func mouseUp(with event: NSEvent) {
        isMovingPanel = false
        lastMouseLocation = nil
        onInteractionChanged?(false)
        if pushedDragCursor {
            NSCursor.pop()
            pushedDragCursor = false
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        let innerFrame = NSRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.bottom,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: bounds.height - contentInsets.top - contentInsets.bottom
        )
        addCursorRect(NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: contentInsets.bottom), cursor: .openHand)
        addCursorRect(NSRect(x: bounds.minX, y: innerFrame.maxY, width: bounds.width, height: contentInsets.top), cursor: .openHand)
        addCursorRect(NSRect(x: bounds.minX, y: innerFrame.minY, width: contentInsets.left, height: innerFrame.height), cursor: .openHand)
        addCursorRect(NSRect(x: innerFrame.maxX, y: innerFrame.minY, width: contentInsets.right, height: innerFrame.height), cursor: .openHand)
    }

    private func move(_ window: NSWindow, by delta: NSPoint) {
        let proposedOrigin = NSPoint(x: window.frame.minX + delta.x, y: window.frame.minY + delta.y)
        let proposedCenter = NSPoint(x: proposedOrigin.x + window.frame.width / 2, y: proposedOrigin.y + window.frame.height / 2)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(proposedCenter) })
            ?? NSScreen.screens.min { distance(from: proposedCenter, to: $0.visibleFrame) < distance(from: proposedCenter, to: $1.visibleFrame) }
        guard let screen else {
            window.setFrameOrigin(proposedOrigin)
            return
        }

        let visibleFrame = screen.visibleFrame
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - window.frame.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - window.frame.height)
        window.setFrameOrigin(NSPoint(
            x: min(max(proposedOrigin.x, visibleFrame.minX), maxX),
            y: min(max(proposedOrigin.y, visibleFrame.minY), maxY)
        ))
    }

    private func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
        let dy = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
        return hypot(dx, dy)
    }
}
