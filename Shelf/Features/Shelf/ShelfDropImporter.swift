//
//  ShelfDropImporter.swift
//  Shelf
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ShelfDropImporter {
    static func loadFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL] else {
            return []
        }

        return objects.compactMap { url in
            let fileURL = url as URL
            return fileURL.isFileURL ? fileURL : nil
        }
    }

    static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: (Int, URL?).self, returning: [URL].self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    (index, await loadFileURL(from: provider))
                }
            }

            var results: [(Int, URL)] = []
            for await (index, url) in group {
                if let url {
                    results.append((index, url))
                }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    static func decodeFileURL(from value: NSSecureCoding?) -> URL? {
        if let url = value as? URL, url.isFileURL {
            return url
        }
        if let url = value as? NSURL, url.isFileURL {
            return url as URL
        }
        if let string = value as? String, let url = URL(string: string), url.isFileURL {
            return url
        }
        if let string = value as? NSString, let url = URL(string: string as String), url.isFileURL {
            return url
        }
        if let data = value as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                return url
            }
            if let string = String(data: data, encoding: .utf8),
               let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
               url.isFileURL {
                return url
            }
            if let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let string = propertyList as? String,
               let url = URL(string: string),
               url.isFileURL {
                return url
            }
        }
        return nil
    }

    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            ? UTType.fileURL.identifier
            : UTType.url.identifier
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { return nil }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: decodeFileURL(from: item as? NSSecureCoding))
            }
        }
    }
}
