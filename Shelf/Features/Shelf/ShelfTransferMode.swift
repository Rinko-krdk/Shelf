import Foundation

enum ShelfDropResult: Equatable {
    case cancelled
    case moved
}

struct ShelfSelectionState: Equatable {
    private(set) var selectedIDs: [ShelfItem.ID] = []
    private(set) var anchorID: ShelfItem.ID?

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
