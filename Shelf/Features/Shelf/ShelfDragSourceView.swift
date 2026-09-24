import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfDragSourceView: NSViewRepresentable {
    let item: ShelfItem
    let itemID: ShelfItem.ID
    let selectedItems: [ShelfItem]
    let onSelect: (ShelfItem.ID, NSEvent.ModifierFlags) -> Void
    let onPromiseCompleted: (ShelfItem.ID, Error?) -> Void
    let onNeedsWriteAccess: ([ShelfItem.ID]) -> Void

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        update(view)
        return view
    }

    func updateNSView(_ view: DragSourceNSView, context: Context) {
        update(view)
    }

    private func update(_ view: DragSourceNSView) {
        view.item = item
        view.itemID = itemID
        view.selectedItems = selectedItems
        view.onSelect = onSelect
        view.onPromiseCompleted = onPromiseCompleted
        view.onNeedsWriteAccess = onNeedsWriteAccess
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    var item: ShelfItem?
    var itemID: ShelfItem.ID = UUID()
    var selectedItems: [ShelfItem] = []
    var onSelect: ((ShelfItem.ID, NSEvent.ModifierFlags) -> Void)?
    var onPromiseCompleted: ((ShelfItem.ID, Error?) -> Void)?
    var onNeedsWriteAccess: (([ShelfItem.ID]) -> Void)?

    private var mouseDownEvent: NSEvent?
    private var didBeginDragging = false
    private var promiseDelegates: [ShelfItem.ID: ShelfFilePromiseDelegate] = [:]
    private let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Shelf.FilePromise"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    private var selectionAtMouseDown = Set<ShelfItem.ID>()
    private var modifiersAtMouseDown: NSEvent.ModifierFlags = []

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didBeginDragging = false
        selectionAtMouseDown = Set(selectedItems.map(\.id))
        modifiersAtMouseDown = event.modifierFlags
        onSelect?(itemID, event.modifierFlags)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didBeginDragging,
              let downEvent = mouseDownEvent,
              hypot(event.locationInWindow.x - downEvent.locationInWindow.x,
                    event.locationInWindow.y - downEvent.locationInWindow.y) >= 4 else {
            return
        }

        let dragItems: [ShelfItem]
        if modifiersAtMouseDown.contains(.command) {
            guard !selectionAtMouseDown.contains(itemID), let item else { return }
            dragItems = selectedItems.contains(where: { $0.id == itemID })
                ? selectedItems
                : selectedItems + [item]
        } else if modifiersAtMouseDown.contains(.shift) {
            guard selectedItems.contains(where: { $0.id == itemID }), let item else { return }
            dragItems = selectedItems.isEmpty ? [item] : selectedItems
        } else if selectionAtMouseDown.contains(itemID) {
            dragItems = selectedItems
        } else if let item {
            dragItems = [item]
        } else {
            dragItems = []
        }
        guard !dragItems.isEmpty,
              dragItems.allSatisfy({ $0.status == .available && $0.resolvedURL?.isFileURL == true }) else {
            return
        }
        let itemsNeedingWriteAccess = dragItems.filter { !$0.bookmarkAllowsWriteAccess }
        guard itemsNeedingWriteAccess.isEmpty else {
            onNeedsWriteAccess?(itemsNeedingWriteAccess.map(\.id))
            mouseDownEvent = nil
            return
        }

        didBeginDragging = true
        promiseDelegates = [:]

        let startPoint = convert(downEvent.locationInWindow, from: nil)
        let draggingItems = dragItems.enumerated().compactMap { index, item -> NSDraggingItem? in
            guard let url = item.resolvedURL else { return nil }
            let candidateType = item.contentTypeIdentifier.flatMap { UTType($0) }
            let fileType = candidateType.flatMap { type in
                type.conforms(to: .data) || type.conforms(to: .directory) ? type : nil
            } ?? .data
            let delegate = ShelfFilePromiseDelegate(item: item, queue: promiseQueue) { [weak self] id, error in
                DispatchQueue.main.async {
                    self?.onPromiseCompleted?(id, error)
                    self?.promiseDelegates[id] = nil
                }
            }
            promiseDelegates[item.id] = delegate
            let promise = NSFilePromiseProvider(fileType: fileType.identifier, delegate: delegate)
            let dragItem = NSDraggingItem(pasteboardWriter: promise)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let offset = CGFloat(index) * 5
            dragItem.setDraggingFrame(
                NSRect(x: startPoint.x + offset, y: startPoint.y + offset, width: 44, height: 44),
                contents: icon
            )
            return dragItem
        }
        guard !draggingItems.isEmpty else { return }

        let session = beginDraggingSession(with: draggingItems, event: downEvent, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        self.mouseDownEvent = nil
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        // The destination materializes the promised file before Shelf removes its source.
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation _: NSDragOperation
    ) {
        // The promise delegate reports success only after the destination file is written.
        didBeginDragging = false
    }
}
