import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ShelfDragItemSelection {
    static func resolve(
        item: ShelfItem?,
        itemID: ShelfItem.ID,
        selectedItems: [ShelfItem],
        selectionAtMouseDown: Set<ShelfItem.ID>
    ) -> [ShelfItem] {
        if selectionAtMouseDown.contains(itemID) { return selectedItems }
        return item.map { [$0] } ?? []
    }
}

enum ShelfDragEligibility {
    static func unavailableItems(in items: [ShelfItem]) -> [ShelfItem] {
        items.filter { $0.status != .available || $0.resolvedURL?.isFileURL != true }
    }

    static func canStartDrag(_ items: [ShelfItem]) -> Bool {
        !items.isEmpty && unavailableItems(in: items).isEmpty
    }
}

struct ShelfDragSourceView: NSViewRepresentable {
    let item: ShelfItem
    let itemID: ShelfItem.ID
    let selectedItems: [ShelfItem]
    let isSelected: Bool
    let onSelect: (ShelfItem.ID, NSEvent.ModifierFlags) -> Void
    let onDoubleClick: (ShelfItem.ID) -> Void
    let onPromiseCompleted: (ShelfItem.ID, Error?) -> Void
    var onDragRejected: ((String) -> Void)? = nil
    let accessibilityIdentifier: String

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
        view.isSelected = isSelected
        view.onSelect = onSelect
        view.onDoubleClick = onDoubleClick
        view.onPromiseCompleted = onPromiseCompleted
        view.onDragRejected = onDragRejected
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel(item.displayName)
        view.setAccessibilityIdentifier(accessibilityIdentifier)
        view.setAccessibilityValue(isSelected ? L10n.string("Selected") : L10n.string("Not selected"))
        view.setAccessibilityHelp(item.warningDescription)
        view.toolTip = item.warningDescription == nil ? nil : item.hoverDescription
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    var item: ShelfItem?
    var itemID: ShelfItem.ID = UUID()
    var selectedItems: [ShelfItem] = []
    var isSelected = false
    var onSelect: ((ShelfItem.ID, NSEvent.ModifierFlags) -> Void)?
    var onDoubleClick: ((ShelfItem.ID) -> Void)?
    var onPromiseCompleted: ((ShelfItem.ID, Error?) -> Void)?
    var onDragRejected: ((String) -> Void)?

    private var mouseDownEvent: NSEvent?
    private var didBeginDragging = false
    private var promiseDelegates: [ShelfItem.ID: ShelfFilePromiseDelegate] = [:]
    private let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Shelf.FilePromise"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    private var selectionAtMouseDown: Set<ShelfItem.ID> = []
    private var selectedItemsAtMouseDown: [ShelfItem] = []
    private var modifiersAtMouseDown: NSEvent.ModifierFlags = []

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didBeginDragging = false
        selectedItemsAtMouseDown = selectedItems
        selectionAtMouseDown = Set(selectedItemsAtMouseDown.map(\.id))
        modifiersAtMouseDown = event.modifierFlags
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didBeginDragging,
              let downEvent = mouseDownEvent,
              hypot(event.locationInWindow.x - downEvent.locationInWindow.x,
                    event.locationInWindow.y - downEvent.locationInWindow.y) >= 4 else {
            return
        }

        let dragItems = ShelfDragItemSelection.resolve(
            item: item,
            itemID: itemID,
            selectedItems: selectedItemsAtMouseDown,
            selectionAtMouseDown: selectionAtMouseDown
        )
        guard !dragItems.isEmpty else {
            rejectDrag(L10n.string("There are no files to drag from Shelf."))
            return
        }
        let unavailableItems = ShelfDragEligibility.unavailableItems(in: dragItems)
        guard ShelfDragEligibility.canStartDrag(dragItems) else {
            rejectDrag(L10n.string("Could not drag out %@. Relocate or remove these items.", unavailableItems.map(\.displayName).joined(separator: ", ")))
            return
        }

        if !selectionAtMouseDown.contains(itemID) {
            onSelect?(itemID, [])
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
        guard draggingItems.count == dragItems.count else {
            rejectDrag(L10n.string("Could not create drag previews for all staged files. Check that the files are still accessible."))
            return
        }

        let session = beginDraggingSession(with: draggingItems, event: downEvent, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        self.mouseDownEvent = nil
    }

    private func rejectDrag(_ message: String) {
        onDragRejected?(message)
        if onDragRejected == nil { NSSound.beep() }
        mouseDownEvent = nil
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownEvent != nil, !didBeginDragging else {
            mouseDownEvent = nil
            return
        }
        if event.clickCount > 1 {
            onDoubleClick?(itemID)
        } else {
            onSelect?(itemID, modifiersAtMouseDown)
        }
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
