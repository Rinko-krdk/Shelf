//
//  ShelfDragProvider.swift
//  Shelf
//

import AppKit
import UniformTypeIdentifiers

enum ShelfDragProvider {
    /// Exposes the original file URL to Finder and other file receiving apps.
    /// The provider never creates or removes a copy of the source file.
    static func makeProvider(for item: ShelfItem) -> NSItemProvider? {
        guard item.status == .available,
              let url = item.resolvedURL,
              url.isFileURL else {
            return nil
        }

        let provider = NSItemProvider()
        provider.registerObject(url as NSURL, visibility: .all)
        return provider
    }
}
