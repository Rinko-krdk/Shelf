# Architecture

Shelf is a macOS 15+ menu bar utility built with SwiftUI and AppKit. It temporarily holds file references, not file contents. The app uses an accessory lifecycle, an `NSPanel`, sandboxed file access, and Swift 5 language mode. The code is the source of truth.

## Components

- `App/AppDelegate`: lifecycle, service composition, session boundaries, shortcuts, shake handling, and refresh.
- `Features/MenuBar` and `Features/Settings`: menu, settings, shortcut, and language controls.
- `Features/Shelf`: panel positioning, stack and list UI, selection, drop importing, and file-promise drag output.
- `State/ShelfViewModel`: observable items, selection-related operations, session cleanup, persistence scheduling, transfer completion, and errors.
- `Domain/ShelfItem`: file reference and status; `ShelfDocument` stores versioned items in display order. Existing decoded duplicates retain distinct IDs; new additions are deduplicated by normalized file location.
- `Services`: security-scoped bookmarks and source deletion; actor-based persistence; Quick Look thumbnails; shortcut, shake, and localization support.

## Sessions and storage

Drops are parsed into file URLs and converted to items. A folder is one item; repeated additions of the same file location are ignored. Activation and ordinary display refresh file status; unavailable items remain visible and can be reselected or removed.

Startup and explicit hiding clear references without deleting source files. Shaking a nonempty Shelf clears and hides it; shaking an empty Shelf displays it. A timeout hides an empty window. Old items are not restored at launch, even though the persistence service supports loading for other uses and tests.

Security-scoped bookmarks provide access; a path or write-access flag alone does not guarantee permission. JSON metadata is stored in Application Support at `<bundle identifier>/shelf-items.json`; file contents are not stored. Saves use generation checks and an atomic replacement. The loader handles old fields, unsupported versions, malformed items, and corrupt documents; startup cleanup is a separate path.

## Transfer and deletion

1. Available selected items are provided through `NSFilePromiseProvider`; source deletion permission is not required to start a drag.
2. The promise delegate coordinates reading and copies each file to its destination. Only a successful write triggers an attempt to delete that source.
3. An item is removed only after source deletion succeeds. Cancellation, rejection, and copy failure must preserve the source and item. Deletion failure retains the item and reports an error, but the destination may already contain a copy.

Manual removal, clearing, and session cleanup only remove references. Destination writing and source deletion are not an atomic transaction. Different target apps may handle promises differently, so these boundaries require real desktop validation using disposable files.
