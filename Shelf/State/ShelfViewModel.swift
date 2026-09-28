//
//  ShelfViewModel.swift
//  Shelf
//

import Combine
import Foundation

enum ShelfViewModelError: LocalizedError {
    case persistence(ShelfPersistenceError)
    case transferFailures([String])

    var errorDescription: String? {
        switch self {
        case let .persistence(error):
            return error.localizedDescription
        case let .transferFailures(names):
            return "以下项目未能完成剪切，已保留在 Shelf：\(names.joined(separator: "、"))"
        }
    }
}

@MainActor
final class ShelfViewModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var lastError: ShelfViewModelError?

    private let fileService: ShelfFileService
    private let persistenceService: ShelfPersistenceService
    private let sourceRemover: (ShelfItem) throws -> Void
    private var saveGeneration = 0
    private var pendingLoadTask: Task<Void, Never>?
    private var pendingSaveTask: Task<Void, Never>?

    init(
        fileService: ShelfFileService? = nil,
        persistenceService: ShelfPersistenceService? = nil,
        sourceRemover: ((ShelfItem) throws -> Void)? = nil
    ) {
        let resolvedFileService = fileService ?? ShelfFileService()
        self.fileService = resolvedFileService
        self.persistenceService = persistenceService ?? ShelfPersistenceService()
        self.sourceRemover = sourceRemover ?? { try resolvedFileService.removeSource(for: $0) }
    }

    func load() {
        lastError = nil
        pendingLoadTask?.cancel()
        let persistenceService = self.persistenceService
        let fileService = self.fileService

        pendingLoadTask = Task { [weak self, persistenceService, fileService] in
            do {
                let document = try await persistenceService.load()
                guard !Task.isCancelled else { return }
                self?.apply(document: document, using: fileService)
            } catch let error as ShelfPersistenceError {
                guard !Task.isCancelled else { return }
                self?.lastError = .persistence(error)
                self?.items = []
            } catch {
                guard !Task.isCancelled else { return }
                self?.lastError = .persistence(.readFailed(error))
                self?.items = []
            }
        }
    }

    func add(urls: [URL]) {
        guard !urls.isEmpty else { return }
        items.append(contentsOf: urls.map(fileService.makeItem(for:)))
        schedulePersistence()
    }

    func add(items newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        items.append(contentsOf: newItems)
        schedulePersistence()
    }

    func remove(id: ShelfItem.ID) {
        guard items.contains(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        schedulePersistence()
    }

    func removeAll() {
        guard !items.isEmpty else { return }
        items.removeAll()
        schedulePersistence()
    }

    /// Starts a fresh temporary Shelf session and ensures stale saved references are cleared.
    func removeAllForSessionBoundary() {
        pendingLoadTask?.cancel()
        items.removeAll()
        lastError = nil
        schedulePersistence()
    }

    /// Called only after AppKit reports a completed drag operation accepted by the destination.
    func completeTransfer(ids: [ShelfItem.ID], result: ShelfDropResult) {
        guard result == .moved else { return }
        let selectedItems = items.filter { ids.contains($0.id) }
        guard !selectedItems.isEmpty else { return }

        var completedIDs = Set<ShelfItem.ID>()
        var failedNames: [String] = []
        for item in selectedItems {
            do {
                try sourceRemover(item)
            } catch {
                failedNames.append(item.displayName)
                continue
            }
            completedIDs.insert(item.id)
        }

        guard !completedIDs.isEmpty || !failedNames.isEmpty else { return }
        if !completedIDs.isEmpty {
            items.removeAll { completedIDs.contains($0.id) }
            schedulePersistence()
        }
        if !failedNames.isEmpty {
            lastError = .transferFailures(failedNames)
        }
    }

    func refreshStatuses() {
        guard !items.isEmpty else { return }
        let refreshedItems = items.map(fileService.restore(_:))
        guard refreshedItems != items else { return }
        items = refreshedItems
        schedulePersistence()
    }

    func reselect(id: ShelfItem.ID, with url: URL) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index] = fileService.relocated(items[index], to: url)
        schedulePersistence()
    }

    func clearError() {
        lastError = nil
    }

    func reportTransferError(_ message: String) {
        lastError = .transferFailures([message])
    }

    /// Test and shutdown helper. Mutations still schedule persistence immediately.
    func waitForPendingOperations() async {
        await pendingLoadTask?.value
        await pendingSaveTask?.value
    }

    private func apply(document: ShelfDocument, using fileService: ShelfFileService) {
        items = document.items.map(fileService.restore(_:))
        if !items.isEmpty {
            schedulePersistence()
        }
    }

    private func schedulePersistence() {
        saveGeneration += 1
        let generation = saveGeneration
        let document = ShelfDocument(items: items)
        pendingSaveTask?.cancel()
        let persistenceService = self.persistenceService

        pendingSaveTask = Task { [weak self, persistenceService, document] in
            do {
                try await persistenceService.save(document, generation: generation)
            } catch let error as ShelfPersistenceError {
                guard !Task.isCancelled else { return }
                self?.lastError = .persistence(error)
            } catch {
                guard !Task.isCancelled else { return }
                self?.lastError = .persistence(.writeFailed(error))
            }
        }
    }
}
