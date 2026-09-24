//
//  ShelfPersistenceService.swift
//  Shelf
//

import Foundation

enum ShelfPersistenceError: LocalizedError {
    case readFailed(Error)
    case corruptData(URL)
    case unsupportedVersion(Int)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readFailed:
            return "Shelf 数据读取失败。"
        case .corruptData:
            return "Shelf 数据文件已损坏，已保留备份并以空 Shelf 启动。"
        case let .unsupportedVersion(version):
            return "Shelf 数据版本不受支持：\(version)。"
        case .writeFailed:
            return "Shelf 数据保存失败。"
        }
    }
}

actor ShelfPersistenceService {
    private let fileURL: URL
    private let fileManager: FileManager
    private var latestGeneration = 0

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
    }

    func load() throws -> ShelfDocument {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ShelfDocument(items: [])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(ShelfDocument.self, from: data)
            guard document.version <= ShelfDocument.currentVersion else {
                throw ShelfPersistenceError.unsupportedVersion(document.version)
            }
            return document
        } catch let error as ShelfPersistenceError {
            throw error
        } catch {
            throw quarantineCorruptFile(error)
        }
    }

    func save(_ document: ShelfDocument, generation: Int) throws {
        guard generation >= latestGeneration else { return }
        latestGeneration = generation

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(document)
        } catch {
            throw ShelfPersistenceError.writeFailed(error)
        }

        let directoryURL = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let temporaryURL = directoryURL.appendingPathComponent(".shelf-items-\(UUID().uuidString).tmp")
            do {
                try data.write(to: temporaryURL, options: .completeFileProtection)
                if fileManager.fileExists(atPath: fileURL.path) {
                    _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
                } else {
                    try fileManager.moveItem(at: temporaryURL, to: fileURL)
                }
            } catch {
                try? fileManager.removeItem(at: temporaryURL)
                throw error
            }
        } catch let error as ShelfPersistenceError {
            throw error
        } catch {
            throw ShelfPersistenceError.writeFailed(error)
        }
    }

    private func quarantineCorruptFile(_ readError: Error) -> ShelfPersistenceError {
        let timestamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(timestamp)-\(UUID().uuidString).json")

        do {
            try fileManager.moveItem(at: fileURL, to: backupURL)
            return .corruptData(backupURL)
        } catch {
            return .readFailed(readError)
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.rinko.shelf"
        return applicationSupportURL
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("shelf-items.json")
    }
}
