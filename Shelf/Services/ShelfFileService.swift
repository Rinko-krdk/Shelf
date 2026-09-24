//
//  ShelfFileService.swift
//  Shelf
//

import Foundation
import UniformTypeIdentifiers

struct BookmarkResolution: Sendable {
    let url: URL?
    let status: ShelfItemStatus
    let refreshedBookmarkData: Data?

    init(url: URL?, status: ShelfItemStatus, refreshedBookmarkData: Data? = nil) {
        self.url = url
        self.status = status
        self.refreshedBookmarkData = refreshedBookmarkData
    }
}

final class ShelfFileService {
    func makeItem(for url: URL) -> ShelfItem {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        let resourceValues = try? url.resourceValues(forKeys: [
            .nameKey,
            .localizedNameKey,
            .contentTypeKey
        ])
        let displayName = resourceValues?.localizedName
            ?? resourceValues?.name
            ?? url.lastPathComponent

        var bookmarkData: Data?
        var status: ShelfItemStatus = .bookmarkResolutionFailed
        do {
            bookmarkData = try makeBookmark(for: url)
            status = .available
        } catch {
            // The item remains visible with its fallback URL and a recoverable status.
        }

        return ShelfItem(
            bookmarkData: bookmarkData,
            bookmarkAllowsWriteAccess: bookmarkData != nil,
            fallbackURLString: url.absoluteString,
            displayName: displayName,
            contentTypeIdentifier: resourceValues?.contentType?.identifier,
            status: status,
            resolvedURL: url
        )
    }

    func restore(_ item: ShelfItem) -> ShelfItem {
        var restoredItem = item
        let resolution = resolve(
            bookmarkData: item.bookmarkData,
            fallbackURL: item.fallbackURL
        )
        restoredItem.resolvedURL = resolution.url
        restoredItem.status = resolution.status
        if let refreshedBookmarkData = resolution.refreshedBookmarkData {
            restoredItem.bookmarkData = refreshedBookmarkData
            restoredItem.bookmarkAllowsWriteAccess = true
        }
        if resolution.status == .available, let url = resolution.url {
            restoredItem.fallbackURLString = url.absoluteString
            let values = try? url.resourceValues(forKeys: [.localizedNameKey, .nameKey, .contentTypeKey])
            restoredItem.displayName = values?.localizedName ?? values?.name ?? url.lastPathComponent
            restoredItem.contentTypeIdentifier = values?.contentType?.identifier
        }
        return restoredItem
    }

    func relocated(_ item: ShelfItem, to url: URL) -> ShelfItem {
        let newItem = makeItem(for: url)
        return ShelfItem(
            id: item.id,
            bookmarkData: newItem.bookmarkData,
            bookmarkAllowsWriteAccess: newItem.bookmarkAllowsWriteAccess,
            fallbackURLString: newItem.fallbackURLString,
            displayName: newItem.displayName,
            contentTypeIdentifier: newItem.contentTypeIdentifier,
            addedAt: item.addedAt,
            status: newItem.status,
            resolvedURL: newItem.resolvedURL
        )
    }

    func removeSource(for item: ShelfItem) throws {
        guard item.bookmarkAllowsWriteAccess,
              let url = item.resolvedURL,
              url.isFileURL else {
            throw CocoaError(.fileWriteNoPermission)
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func resolve(bookmarkData: Data?, fallbackURL: URL?) -> BookmarkResolution {
        guard let bookmarkData else {
            return BookmarkResolution(url: fallbackURL, status: .bookmarkResolutionFailed)
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                return BookmarkResolution(url: url, status: .inaccessible)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            guard FileManager.default.fileExists(atPath: url.path) else {
                return BookmarkResolution(url: url, status: .missing)
            }

            do {
                _ = try url.checkResourceIsReachable()
            } catch {
                return BookmarkResolution(url: url, status: .inaccessible)
            }

            if isStale {
                do {
                    let refreshedData = try makeBookmark(for: url)
                    return BookmarkResolution(
                        url: url,
                        status: .available,
                        refreshedBookmarkData: refreshedData
                    )
                } catch {
                    return BookmarkResolution(url: url, status: .staleBookmark)
                }
            }

            return BookmarkResolution(url: url, status: .available)
        } catch {
            let fallbackStatus: ShelfItemStatus
            if let fallbackURL, !FileManager.default.fileExists(atPath: fallbackURL.path) {
                fallbackStatus = .missing
            } else {
                fallbackStatus = .bookmarkResolutionFailed
            }
            return BookmarkResolution(url: fallbackURL, status: fallbackStatus)
        }
    }
}
