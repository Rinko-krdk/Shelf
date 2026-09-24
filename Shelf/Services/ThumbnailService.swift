//
//  ThumbnailService.swift
//  Shelf
//

import AppKit
import Combine
import Foundation
import QuickLookThumbnailing

@MainActor
final class ThumbnailService: ObservableObject {
    private var cache: [UUID: NSImage] = [:]
    private var requests: [UUID: QLThumbnailGenerator.Request] = [:]
    private var requestTokens: [UUID: UUID] = [:]

    func thumbnail(for item: ShelfItem, size: CGSize) async -> NSImage? {
        if let cached = cache[item.id] {
            return cached
        }
        guard item.status == .available,
              let url = item.resolvedURL else {
            return nil
        }
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        cancelThumbnail(for: item.id)
        let token = UUID()
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )
        requests[item.id] = request
        requestTokens[item.id] = token

        let image: NSImage? = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [self] thumbnail, _ in
                    Task { @MainActor in
                        guard self.requestTokens[item.id] == token else {
                            continuation.resume(returning: nil)
                            return
                        }
                        self.requests[item.id] = nil
                        self.requestTokens[item.id] = nil
                        let image = thumbnail?.nsImage
                        if let image {
                            self.cache[item.id] = image
                        }
                        continuation.resume(returning: image)
                    }
                }
            }
        } onCancel: {
            QLThumbnailGenerator.shared.cancel(request)
        }

        return Task.isCancelled ? nil : image
    }

    func cancelThumbnail(for id: UUID) {
        requestTokens[id] = nil
        if let request = requests.removeValue(forKey: id) {
            QLThumbnailGenerator.shared.cancel(request)
        }
    }

    func removeCachedThumbnail(for id: UUID) {
        cancelThumbnail(for: id)
        cache[id] = nil
    }

    func retainThumbnails(for ids: Set<UUID>) {
        let staleCacheIDs = cache.keys.filter { !ids.contains($0) }
        for id in staleCacheIDs {
            cache[id] = nil
        }
        let staleRequestIDs = requests.keys.filter { !ids.contains($0) }
        for id in staleRequestIDs {
            cancelThumbnail(for: id)
        }
    }
}
