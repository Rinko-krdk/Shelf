//
//  ShelfItem.swift
//  Shelf
//

import Foundation

nonisolated enum ShelfItemStatus: String, Codable, Equatable, Sendable {
    case available
    case missing
    case inaccessible
    case staleBookmark
    case bookmarkResolutionFailed
}

nonisolated struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var bookmarkData: Data?
    var bookmarkAllowsWriteAccess: Bool
    var fallbackURLString: String?
    var displayName: String
    var contentTypeIdentifier: String?
    var addedAt: Date
    var status: ShelfItemStatus

    /// This is populated while the app is running and is intentionally not persisted.
    var resolvedURL: URL?

    /// Opening errors belong to this session, not the persisted file reference or availability status.
    var hasOpenFailure = false

    init(
        id: UUID = UUID(),
        bookmarkData: Data? = nil,
        bookmarkAllowsWriteAccess: Bool = false,
        fallbackURLString: String? = nil,
        displayName: String,
        contentTypeIdentifier: String? = nil,
        addedAt: Date = Date(),
        status: ShelfItemStatus = .bookmarkResolutionFailed,
        resolvedURL: URL? = nil
    ) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.bookmarkAllowsWriteAccess = bookmarkAllowsWriteAccess
        self.fallbackURLString = fallbackURLString
        self.displayName = displayName
        self.contentTypeIdentifier = contentTypeIdentifier
        self.addedAt = addedAt
        self.status = status
        self.resolvedURL = resolvedURL
    }

    var fallbackURL: URL? {
        guard let fallbackURLString else { return nil }
        return URL(string: fallbackURLString)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bookmarkData
        case bookmarkAllowsWriteAccess
        case fallbackURLString
        case displayName
        case contentTypeIdentifier
        case addedAt
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedFallback = try container.decodeIfPresent(String.self, forKey: .fallbackURLString)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        bookmarkAllowsWriteAccess = try container.decodeIfPresent(Bool.self, forKey: .bookmarkAllowsWriteAccess) ?? false
        fallbackURLString = decodedFallback
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? decodedFallback.flatMap { URL(string: $0)?.lastPathComponent }
            ?? Self.untitledFileName()
        contentTypeIdentifier = try container.decodeIfPresent(String.self, forKey: .contentTypeIdentifier)
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        status = try container.decodeIfPresent(ShelfItemStatus.self, forKey: .status) ?? .bookmarkResolutionFailed
        resolvedURL = nil
    }

    private static func untitledFileName() -> String {
        let language = UserDefaults.standard.string(forKey: LanguagePreference.defaultsKey) ?? "en"
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: "Untitled File", value: "Untitled File", table: nil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(bookmarkAllowsWriteAccess, forKey: .bookmarkAllowsWriteAccess)
        try container.encodeIfPresent(fallbackURLString, forKey: .fallbackURLString)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(contentTypeIdentifier, forKey: .contentTypeIdentifier)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(status, forKey: .status)
    }
}

nonisolated struct ShelfDocument: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    var items: [ShelfItem]

    init(version: Int = ShelfDocument.currentVersion, items: [ShelfItem]) {
        self.version = version
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1

        var decodedItems: [ShelfItem] = []
        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
        while !itemsContainer.isAtEnd {
            let itemDecoder = try itemsContainer.superDecoder()
            if let item = try? ShelfItem(from: itemDecoder) {
                decodedItems.append(item)
            }
        }
        items = decodedItems
    }
}
