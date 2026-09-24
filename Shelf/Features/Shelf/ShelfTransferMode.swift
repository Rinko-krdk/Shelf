import AppKit
import Combine
import Foundation
import SwiftUI

enum ShelfDropResult: Equatable {
    case cancelled
    case moved
}

struct ShelfSelectionState: Equatable {
    private(set) var selectedIDs: [ShelfItem.ID] = []
    private(set) var anchorID: ShelfItem.ID?

    mutating func clear() {
        selectedIDs = []
        anchorID = nil
    }

    mutating func replace(with ids: Set<ShelfItem.ID>, orderedIDs: [ShelfItem.ID]) {
        selectedIDs = orderedIDs.filter(ids.contains)
        anchorID = selectedIDs.last
    }

    mutating func add(_ ids: Set<ShelfItem.ID>, orderedIDs: [ShelfItem.ID]) {
        let combinedIDs = Set(selectedIDs).union(ids)
        selectedIDs = orderedIDs.filter(combinedIDs.contains)
        if let lastAddedID = orderedIDs.last(where: ids.contains) {
            anchorID = lastAddedID
        }
    }

    func ids(intersecting rect: CGRect, in frames: [ShelfItem.ID: CGRect], orderedIDs: [ShelfItem.ID]) -> Set<ShelfItem.ID> {
        Set(orderedIDs.filter { id in
            guard let frame = frames[id] else { return false }
            return frame.intersects(rect)
        })
    }

    mutating func select(
        _ id: ShelfItem.ID,
        command: Bool,
        shift: Bool,
        orderedIDs: [ShelfItem.ID]
    ) {
        if shift, let anchorID,
           let anchorIndex = orderedIDs.firstIndex(of: anchorID),
           let clickedIndex = orderedIDs.firstIndex(of: id) {
            let lower = min(anchorIndex, clickedIndex)
            let upper = max(anchorIndex, clickedIndex)
            let rangeIDs = Array(orderedIDs[lower...upper])
            if command {
                selectedIDs = orderedIDs.filter { selectedIDs.contains($0) || rangeIDs.contains($0) }
            } else {
                selectedIDs = rangeIDs
            }
            return
        }

        if !command, !shift, selectedIDs.contains(id) {
            return
        }

        if command {
            if selectedIDs.contains(id) {
                selectedIDs.removeAll { $0 == id }
            } else {
                selectedIDs.append(id)
                selectedIDs = orderedIDs.filter { selectedIDs.contains($0) }
            }
            anchorID = id
        } else {
            selectedIDs = [id]
            anchorID = id
        }
    }

    mutating func retain(_ validIDs: Set<ShelfItem.ID>) {
        selectedIDs.removeAll { !validIDs.contains($0) }
        if let anchorID, !validIDs.contains(anchorID) {
            self.anchorID = selectedIDs.last
        }
    }
}

@MainActor
final class ShelfSelectionGestureCoordinator: ObservableObject {
    private(set) var cardFrames: [ShelfItem.ID: CGRect] = [:]
    private(set) var orderedIDs: [ShelfItem.ID] = []
    private(set) var marqueeRect: CGRect?

    weak var captureView: ShelfSelectionCaptureNSView?
    private var lastSweepPoint: NSPoint?

    func updateLayout(frames: [ShelfItem.ID: CGRect], orderedIDs: [ShelfItem.ID]) {
        cardFrames = frames
        self.orderedIDs = orderedIDs
    }

    func ids(intersecting rect: CGRect) -> Set<ShelfItem.ID> {
        Set(orderedIDs.filter { cardFrames[$0]?.intersects(rect) == true })
    }

    func attach(_ view: ShelfSelectionCaptureNSView) {
        captureView = view
    }

    func beginSweep(at point: NSPoint, including id: ShelfItem.ID?) -> Set<ShelfItem.ID> {
        lastSweepPoint = point
        var ids = Set<ShelfItem.ID>()
        if let id { ids.insert(id) }
        return ids
    }

    func updateSweep(to point: NSPoint) -> Set<ShelfItem.ID> {
        guard let lastSweepPoint else {
            self.lastSweepPoint = point
            return []
        }

        let distance = hypot(point.x - lastSweepPoint.x, point.y - lastSweepPoint.y)
        let steps = max(1, Int(ceil(distance / 4)))
        var passedIDs = Set<ShelfItem.ID>()
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let sample = NSPoint(
                x: lastSweepPoint.x + (point.x - lastSweepPoint.x) * progress,
                y: lastSweepPoint.y + (point.y - lastSweepPoint.y) * progress
            )
            for id in orderedIDs {
                guard let frame = cardFrames[id], frame.insetBy(dx: -3, dy: -3).contains(sample) else { continue }
                passedIDs.insert(id)
            }
        }
        self.lastSweepPoint = point
        return passedIDs
    }

    func endSweep() {
        lastSweepPoint = nil
    }

    func beginBlankGesture() {
        marqueeRect = nil
        lastSweepPoint = nil
        captureView?.needsDisplay = true
    }

    func updateBlankGesture(from start: NSPoint, to point: NSPoint, isSweep: Bool) -> Set<ShelfItem.ID> {
        if isSweep {
            let initialIDs = lastSweepPoint == nil ? beginSweep(at: start, including: nil) : []
            return initialIDs.union(updateSweep(to: point))
        }

        let rect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: max(abs(point.x - start.x), 1),
            height: max(abs(point.y - start.y), 1)
        )
        marqueeRect = rect
        captureView?.needsDisplay = true
        return ids(intersecting: rect)
    }

    func endBlankGesture() {
        endSweep()
        marqueeRect = nil
        captureView?.needsDisplay = true
    }
}

@MainActor
final class ShelfSelectionCaptureNSView: NSView {
    var gestureCoordinator: ShelfSelectionGestureCoordinator?
    var onBlankClick: (() -> Void)?
    var onMarqueeSelection: ((Set<ShelfItem.ID>) -> Void)?
    var onSweepSelection: ((Set<ShelfItem.ID>) -> Void)?
    var onCardClick: ((ShelfItem.ID, NSEvent.ModifierFlags) -> Void)?
    private var mouseDownPoint: NSPoint?
    private var mouseDownModifiers: NSEvent.ModifierFlags = []
    private var mouseDownItemID: ShelfItem.ID?
    private var didDrag = false

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(convert(point, from: superview)) else { return nil }
        let localPoint = convert(point, from: superview)
        let itemID = gestureCoordinator?.orderedIDs.first { id in
            gestureCoordinator?.cardFrames[id]?.contains(localPoint) == true
        }
        if itemID != nil && !NSEvent.modifierFlags.contains(.shift) {
            return nil
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseDownPoint = point
        mouseDownModifiers = event.modifierFlags
        mouseDownItemID = gestureCoordinator?.orderedIDs.first { id in
            gestureCoordinator?.cardFrames[id]?.contains(point) == true
        }
        didDrag = false
        if mouseDownItemID == nil {
            gestureCoordinator?.beginBlankGesture()
            if !event.modifierFlags.contains(.shift) { onBlankClick?() }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        let isBeyondThreshold = hypot(point.x - start.x, point.y - start.y) >= 4
        let didJustBeginDragging = isBeyondThreshold && !didDrag
        didDrag = didDrag || isBeyondThreshold
        guard didDrag else { return }

        if mouseDownItemID != nil {
            if didJustBeginDragging {
                let initialIDs = gestureCoordinator?.beginSweep(at: start, including: mouseDownItemID) ?? []
                if !initialIDs.isEmpty { onSweepSelection?(initialIDs) }
            }
            let passedIDs = gestureCoordinator?.updateSweep(to: point) ?? []
            if !passedIDs.isEmpty { onSweepSelection?(passedIDs) }
        } else {
            let ids = gestureCoordinator?.updateBlankGesture(
                from: start,
                to: point,
                isSweep: mouseDownModifiers.contains(.shift)
            ) ?? []
            if mouseDownModifiers.contains(.shift) {
                if !ids.isEmpty { onSweepSelection?(ids) }
            } else {
                onMarqueeSelection?(ids)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let mouseDownItemID {
            if didDrag {
                let ids = gestureCoordinator?.updateSweep(to: point) ?? []
                if !ids.isEmpty { onSweepSelection?(ids) }
                gestureCoordinator?.endSweep()
            } else {
                onCardClick?(mouseDownItemID, mouseDownModifiers)
            }
        } else {
            if didDrag {
                if mouseDownModifiers.contains(.shift) {
                    let ids = gestureCoordinator?.updateSweep(to: point) ?? []
                    if !ids.isEmpty { onSweepSelection?(ids) }
                } else {
                    let ids = gestureCoordinator?.updateBlankGesture(from: start, to: point, isSweep: false) ?? []
                    onMarqueeSelection?(ids)
                }
            }
            gestureCoordinator?.endBlankGesture()
        }
        mouseDownPoint = nil
        mouseDownItemID = nil
        didDrag = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let rect = gestureCoordinator?.marqueeRect, !rect.isEmpty else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
        rect.fill()
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1
        path.stroke()
    }
}

struct ShelfSelectionCaptureView: NSViewRepresentable {
    let coordinator: ShelfSelectionGestureCoordinator
    let onBlankClick: () -> Void
    let onMarqueeSelection: (Set<ShelfItem.ID>) -> Void
    let onSweepSelection: (Set<ShelfItem.ID>) -> Void
    let onCardClick: (ShelfItem.ID, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> ShelfSelectionCaptureNSView {
        let view = ShelfSelectionCaptureNSView()
        view.gestureCoordinator = coordinator
        view.onBlankClick = onBlankClick
        view.onMarqueeSelection = onMarqueeSelection
        view.onSweepSelection = onSweepSelection
        view.onCardClick = onCardClick
        coordinator.attach(view)
        return view
    }

    func updateNSView(_ view: ShelfSelectionCaptureNSView, context: Context) {
        view.gestureCoordinator = coordinator
        view.onBlankClick = onBlankClick
        view.onMarqueeSelection = onMarqueeSelection
        view.onSweepSelection = onSweepSelection
        view.onCardClick = onCardClick
        coordinator.attach(view)
    }
}

struct ShelfWindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragHandleNSView()
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

private final class WindowDragHandleNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
