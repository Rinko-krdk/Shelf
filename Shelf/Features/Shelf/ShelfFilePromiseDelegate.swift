import AppKit
import UniformTypeIdentifiers

final class ShelfFilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    let item: ShelfItem
    private let onCompletion: (ShelfItem.ID, Error?) -> Void
    private let queue: OperationQueue

    init(
        item: ShelfItem,
        queue: OperationQueue,
        onCompletion: @escaping (ShelfItem.ID, Error?) -> Void
    ) {
        self.item = item
        self.queue = queue
        self.onCompletion = onCompletion
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        item.displayName
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        queue
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo destinationURL: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let sourceURL = item.resolvedURL, sourceURL.isFileURL else {
            let error = CocoaError(.fileNoSuchFile)
            completionHandler(error)
            onCompletion(item.id, error)
            return
        }

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        var coordinationError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        let error = copyError ?? coordinationError
        completionHandler(error)
        onCompletion(item.id, error)
    }
}
