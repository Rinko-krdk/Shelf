//
//  ShelfTests.swift
//  ShelfTests
//
//  Created by Rinko  on 2026/09/24.
//

import CoreGraphics
import AppKit
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

    @Test func legacyShelfItemsDefaultToReadOnlyBookmarks() throws {
        let data = Data(#"{"displayName":"legacy.txt","addedAt":"2026-09-24T00:00:00Z","status":"available"}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(ShelfItem.self, from: data)

        #expect(!item.bookmarkAllowsWriteAccess)
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

    @Test func fileServiceDeletesOnlyWithWriteAuthorizationFlag() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("authorized-cut.txt")
        try Data("cut".utf8).write(to: sourceURL)
        let service = ShelfFileService()
        let readOnlyItem = ShelfItem(displayName: "authorized-cut.txt", resolvedURL: sourceURL)

        #expect(throws: CocoaError.self) {
            try service.removeSource(for: readOnlyItem)
        }
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))

        let writableItem = ShelfItem(
            bookmarkAllowsWriteAccess: true,
            displayName: "authorized-cut.txt",
            resolvedURL: sourceURL
        )
        try service.removeSource(for: writableItem)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
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

    @Test func dropImporterReadsFileURLsFromPasteboardInOrder() throws {
        let pasteboard = NSPasteboard(name: .init("ShelfTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let urls = [
            URL(fileURLWithPath: "/tmp/first.txt"),
            URL(fileURLWithPath: "/tmp/second.txt")
        ]
        #expect(pasteboard.writeObjects(urls as [NSURL]))
        #expect(ShelfDropImporter.loadFileURLs(from: pasteboard) == urls)
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

    @Test func shortcutUsesDefaultAndRejectedCombinationKeepsCurrentValue() {
        let suiteName = "ShelfTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let shortcutService = ShortcutService(defaults: defaults)

        #expect(shortcutService.shortcut == .default)
        #expect(shortcutService.shortcut.displayName == "⌃⌥Space")

        let rejected = ShelfShortcut(keyCode: 0, modifierFlags: 0)
        #expect(!shortcutService.setShortcut(rejected))
        #expect(shortcutService.shortcut == .default)
        #expect(shortcutService.lastError != nil)
    }

    @Test func reselectingFileKeepsItemIdentityAndOrder() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appendingPathComponent("first.txt")
        let replacementURL = directory.appendingPathComponent("replacement 中文.txt")
        try Data("first".utf8).write(to: firstURL)
        try Data("replacement".utf8).write(to: replacementURL)

        let persistence = ShelfPersistenceService(fileURL: directory.appendingPathComponent("shelf.json"))
        let viewModel = ShelfViewModel(persistenceService: persistence)
        viewModel.add(urls: [firstURL, replacementURL])
        let originalID = viewModel.items[0].id
        let secondID = viewModel.items[1].id

        viewModel.reselect(id: originalID, with: replacementURL)
        await viewModel.waitForPendingOperations()

        #expect(viewModel.items.map(\.id) == [originalID, secondID])
        #expect(viewModel.items[0].displayName == "replacement 中文.txt")
        #expect(viewModel.items[0].resolvedURL == replacementURL)
    }

    @Test func selectionSupportsCommandToggleAndShiftRange() {
        let ids = (0..<4).map { _ in UUID() }
        var selection = ShelfSelectionState()

        selection.select(ids[0], command: false, shift: false, orderedIDs: ids)
        selection.select(ids[2], command: true, shift: false, orderedIDs: ids)
        #expect(selection.selectedIDs == [ids[0], ids[2]])

        selection.select(ids[3], command: false, shift: true, orderedIDs: ids)
        #expect(selection.selectedIDs == [ids[2], ids[3]])

        selection.select(ids[1], command: true, shift: false, orderedIDs: ids)
        #expect(selection.selectedIDs == [ids[1], ids[2], ids[3]])
    }

    @Test func selectionCanClearAndReplaceInShelfOrder() {
        let ids = (0..<4).map { _ in UUID() }
        var selection = ShelfSelectionState()

        selection.add([ids[3], ids[1]], orderedIDs: ids)
        #expect(selection.selectedIDs == [ids[1], ids[3]])

        selection.replace(with: [ids[2], ids[0]], orderedIDs: ids)
        #expect(selection.selectedIDs == [ids[0], ids[2]])

        selection.clear()
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.anchorID == nil)
    }

    @Test func commandSelectionTogglesAnAlreadySelectedItemOff() {
        let ids = (0..<2).map { _ in UUID() }
        var selection = ShelfSelectionState()

        selection.select(ids[0], command: false, shift: false, orderedIDs: ids)
        selection.select(ids[0], command: true, shift: false, orderedIDs: ids)

        #expect(selection.selectedIDs.isEmpty)
    }

    @Test func marqueeSelectsEveryCardIntersectingTheRectangle() {
        let ids = (0..<3).map { _ in UUID() }
        let frames: [UUID: CGRect] = [
            ids[0]: CGRect(x: 0, y: 0, width: 40, height: 40),
            ids[1]: CGRect(x: 50, y: 0, width: 40, height: 40),
            ids[2]: CGRect(x: 100, y: 0, width: 40, height: 40)
        ]
        let selection = ShelfSelectionState()

        let hits = selection.ids(
            intersecting: CGRect(x: 35, y: 10, width: 25, height: 20),
            in: frames,
            orderedIDs: ids
        )

        #expect(hits == [ids[0], ids[1]])
    }

    @Test func retainingItemsRemovesSelectionAndRepairsAnchor() {
        let ids = (0..<3).map { _ in UUID() }
        var selection = ShelfSelectionState()
        selection.add([ids[0], ids[2]], orderedIDs: ids)

        selection.retain([ids[0]])

        #expect(selection.selectedIDs == [ids[0]])
        #expect(selection.anchorID == ids[0])
    }

    @Test func shiftSweepFindsEveryCardAlongThePointerPath() {
        let ids = (0..<3).map { _ in UUID() }
        let coordinator = ShelfSelectionGestureCoordinator()
        coordinator.updateLayout(
            frames: [
                ids[0]: CGRect(x: 15, y: 10, width: 20, height: 20),
                ids[1]: CGRect(x: 45, y: 10, width: 20, height: 20),
                ids[2]: CGRect(x: 75, y: 10, width: 20, height: 20)
            ],
            orderedIDs: ids
        )
        let captureView = ShelfSelectionCaptureNSView(frame: CGRect(x: 0, y: 0, width: 120, height: 40))
        coordinator.attach(captureView)
        _ = coordinator.beginSweep(at: NSPoint(x: 0, y: 20), including: nil)

        let passedIDs = coordinator.updateSweep(to: NSPoint(x: 110, y: 20))

        #expect(passedIDs == Set(ids))
    }

    @Test func successfulMoveDeletesSourceAndRemovesShelfItem() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("move.txt")
        try Data("move".utf8).write(to: sourceURL)
        let viewModel = ShelfViewModel(
            persistenceService: ShelfPersistenceService(fileURL: directory.appendingPathComponent("shelf.json")),
            sourceRemover: { item in
                guard let url = item.resolvedURL else { throw CocoaError(.fileNoSuchFile) }
                try FileManager.default.removeItem(at: url)
            }
        )
        viewModel.add(urls: [sourceURL])
        let id = try #require(viewModel.items.first?.id)

        viewModel.completeTransfer(ids: [id], result: .moved)
        await viewModel.waitForPendingOperations()

        #expect(viewModel.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test func cancelledDropDoesNotChangeSourceOrShelf() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("cancel.txt")
        try Data("cancel".utf8).write(to: sourceURL)
        let viewModel = ShelfViewModel(
            persistenceService: ShelfPersistenceService(fileURL: directory.appendingPathComponent("shelf.json"))
        )
        viewModel.add(urls: [sourceURL])
        let id = try #require(viewModel.items.first?.id)

        viewModel.completeTransfer(ids: [id], result: .cancelled)

        #expect(viewModel.items.map(\.id) == [id])
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test func partialMoveFailureKeepsFailedItemsInShelf() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let successURL = directory.appendingPathComponent("success.txt")
        let failureURL = directory.appendingPathComponent("failure.txt")
        try Data("success".utf8).write(to: successURL)
        try Data("failure".utf8).write(to: failureURL)
        let viewModel = ShelfViewModel(
            persistenceService: ShelfPersistenceService(fileURL: directory.appendingPathComponent("shelf.json")),
            sourceRemover: { item in
                guard let url = item.resolvedURL else { throw CocoaError(.fileNoSuchFile) }
                if url == failureURL { throw CocoaError(.fileWriteNoPermission) }
                try FileManager.default.removeItem(at: url)
            }
        )
        viewModel.add(urls: [successURL, failureURL])
        let ids = viewModel.items.map(\.id)

        viewModel.completeTransfer(ids: ids, result: .moved)
        await viewModel.waitForPendingOperations()

        #expect(viewModel.items.map(\.fallbackURL) == [failureURL])
        #expect(!FileManager.default.fileExists(atPath: successURL.path))
        #expect(FileManager.default.fileExists(atPath: failureURL.path))
        #expect(viewModel.lastError != nil)
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
