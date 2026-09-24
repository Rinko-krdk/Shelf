//
//  ShelfTests.swift
//  ShelfTests
//
//  Created by Rinko  on 2026/09/24.
//

import Foundation
import UniformTypeIdentifiers
import Testing
@testable import Shelf

@MainActor
struct ShelfTests {

    @Test func shelfDocumentRoundTripsOrderAndDuplicates() throws {
        let firstURL = URL(fileURLWithPath: "/tmp/first.txt")
        let first = ShelfItem(
            bookmarkData: Data("first-bookmark".utf8),
            fallbackURLString: firstURL.absoluteString,
            displayName: "first.txt",
            contentTypeIdentifier: "public.plain-text",
            status: .available
        )
        let second = ShelfItem(
            bookmarkData: Data("first-bookmark".utf8),
            fallbackURLString: firstURL.absoluteString,
            displayName: "first.txt",
            contentTypeIdentifier: "public.plain-text",
            status: .missing
        )

        let document = ShelfDocument(items: [first, second])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(ShelfDocument.self, from: data)

        #expect(restored.version == ShelfDocument.currentVersion)
        #expect(restored.items.map(\.id) == [first.id, second.id])
        #expect(restored.items[0].displayName == "first.txt")
        #expect(restored.items[1].status == .missing)
        #expect(restored.items[0].resolvedURL == nil)
    }

    @Test func fileServiceCapturesFileMetadataAndFallbackURL() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("中文 文件.txt")
        try Data("content".utf8).write(to: sourceURL)

        let item = ShelfFileService().makeItem(for: sourceURL)

        #expect(item.displayName == "中文 文件.txt")
        #expect(item.fallbackURL == sourceURL)
        #expect(item.resolvedURL == sourceURL)
    }

    @Test func dropImporterDecodesFileURLsAndRejectsWebURLs() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/中文 文件 😀.txt")

        #expect(ShelfDropImporter.decodeFileURL(from: fileURL as NSURL) == fileURL)
        #expect(ShelfDropImporter.decodeFileURL(from: fileURL.absoluteString as NSString) == fileURL)
        #expect(
            ShelfDropImporter.decodeFileURL(from: fileURL.dataRepresentation as NSData) == fileURL
        )
        let webURL = try #require(URL(string: "https://example.com"))
        #expect(ShelfDropImporter.decodeFileURL(from: webURL as NSURL) == nil)
    }

    @Test func dropImporterPreservesProviderOrderAndDuplicates() async throws {
        let firstURL = URL(fileURLWithPath: "/tmp/first.txt")
        let secondURL = URL(fileURLWithPath: "/tmp/second.txt")
        let providers = [
            makeFileURLProvider(firstURL, delay: 0.04),
            makeFileURLProvider(secondURL, delay: 0.01),
            makeFileURLProvider(firstURL, delay: 0.02)
        ]

        let urls = await ShelfDropImporter.loadFileURLs(from: providers)

        #expect(urls == [firstURL, secondURL, firstURL])
    }

    @Test func storePersistsOrderAndKeepsDuplicateItems() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstURL = directory.appendingPathComponent("first.txt")
        try Data("first".utf8).write(to: firstURL)
        let persistenceService = ShelfPersistenceService(
            fileURL: directory.appendingPathComponent("shelf-items.json")
        )
        let viewModel = ShelfViewModel(persistenceService: persistenceService)

        viewModel.add(urls: [firstURL, firstURL])
        await viewModel.waitForPendingOperations()

        let restoredViewModel = ShelfViewModel(
            persistenceService: persistenceService
        )
        restoredViewModel.load()
        await restoredViewModel.waitForPendingOperations()

        #expect(restoredViewModel.items.count == 2)
        #expect(restoredViewModel.items.map(\.displayName) == ["first.txt", "first.txt"])
        #expect(restoredViewModel.items[0].id != restoredViewModel.items[1].id)
    }

    @Test func directoryIsAddedAsOneItem() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let folderURL = directory.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let viewModel = ShelfViewModel()
        viewModel.add(urls: [folderURL])

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].displayName == "Folder")
        #expect(viewModel.items[0].resolvedURL == folderURL)
    }

    @Test func storeRestoresStatusWithoutDroppingItem() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("shelf-items.json")
        let item = ShelfItem(
            bookmarkData: Data("missing-bookmark".utf8),
            fallbackURLString: URL(fileURLWithPath: "/tmp/missing.txt").absoluteString,
            displayName: "missing.txt",
            status: .available
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(ShelfDocument(items: [item])).write(to: fileURL)

        let viewModel = ShelfViewModel(
            fileService: ShelfFileService(),
            persistenceService: ShelfPersistenceService(fileURL: fileURL)
        )
        viewModel.load()
        await viewModel.waitForPendingOperations()

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].status == .missing)
    }

    @Test func corruptDataIsQuarantined() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("shelf-items.json")
        try Data("not-json".utf8).write(to: fileURL)

        let viewModel = ShelfViewModel(
            persistenceService: ShelfPersistenceService(fileURL: fileURL)
        )
        viewModel.load()
        await viewModel.waitForPendingOperations()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.lastError != nil)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(files.contains { $0.lastPathComponent.contains("corrupt-") })
    }

    @Test func deletingItemDoesNotDeleteSourceFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: sourceURL)
        let viewModel = ShelfViewModel(
            persistenceService: ShelfPersistenceService(
                fileURL: directory.appendingPathComponent("shelf-items.json")
            )
        )
        viewModel.add(urls: [sourceURL])
        let itemID = try #require(viewModel.items.first?.id)
        viewModel.remove(id: itemID)
        await viewModel.waitForPendingOperations()

        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(viewModel.items.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeFileURLProvider(_ url: URL, delay: TimeInterval) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            let progress = Progress(totalUnitCount: 1)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                completion(url.dataRepresentation, nil)
                progress.completedUnitCount = 1
            }
            return progress
        }
        return provider
    }
}
