//
//  ShelfViewModel.swift
//  Shelf
//

import Combine
import Foundation

enum ShelfViewModelError: LocalizedError {
    case persistence(ShelfPersistenceError)

    var errorDescription: String? {
        switch self {
        case let .persistence(error):
            return error.localizedDescription
        }
    }
}

@MainActor
final class ShelfViewModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var lastError: ShelfViewModelError?

    private let fileService: ShelfFileService
    private let persistenceService: ShelfPersistenceService
    private var saveGeneration = 0
    private var pendingLoadTask: Task<Void, Never>?
    private var pendingSaveTask: Task<Void, Never>?

    init(
        fileService: ShelfFileService? = nil,
        persistenceService: ShelfPersistenceService? = nil
    ) {
        self.fileService = fileService ?? ShelfFileService()
        self.persistenceService = persistenceService ?? ShelfPersistenceService()
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
