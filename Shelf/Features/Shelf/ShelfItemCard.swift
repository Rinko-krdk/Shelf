//
//  ShelfItemCard.swift
//  Shelf
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfItemCard: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    let item: ShelfItem
    @ObservedObject var thumbnailService: ThumbnailService
    let isSelected: Bool
    let selectedItems: [ShelfItem]
    let onSelect: (ShelfItem.ID, NSEvent.ModifierFlags) -> Void
    let onPromiseCompleted: (ShelfItem.ID, Error?) -> Void
    let onDragRejected: (String) -> Void
    let onRemove: (ShelfItem.ID) -> Void
    let onRelocate: (ShelfItem.ID, URL) -> Void

    @State private var thumbnail: NSImage?
    @State private var isConfirmingRemoval = false
    @State private var isHovered = false

    private let previewSize = CGSize(width: 132, height: 96)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                } else {
                    fallbackImage
                }

                ShelfDragSourceView(
                    item: item,
                    itemID: item.id,
                    selectedItems: selectedItems,
                    isSelected: isSelected,
                    onSelect: onSelect,
                    onDoubleClick: { _ in },
                    onPromiseCompleted: onPromiseCompleted,
                    onDragRejected: onDragRejected,
                    accessibilityIdentifier: "shelf-item-drag-source-\(item.id.uuidString)"
                )

                if item.status != .available {
                    Image(systemName: statusSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.orange, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(5)
                }

                Button {
                    isConfirmingRemoval = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 22, height: 22)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.string("Remove from Shelf"))
                .accessibilityLabel(L10n.string("Remove %@", item.displayName))
                .accessibilityIdentifier("remove-shelf-item-\(item.id.uuidString)")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(5)
                .opacity(isHovered ? 1 : 0.55)
            }
            .frame(height: previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.displayName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
                .help(item.displayName)
                .accessibilityLabel(item.displayName)
                .onTapGesture {
                    onSelect(item.id, NSEvent.modifierFlags)
                }

            if item.status != .available {
                Button(action: chooseReplacement) {
                    Label(L10n.string("Choose Again…"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                }
                .buttonStyle(.link)
                .help(statusDescription)
                .accessibilityIdentifier("reselect-shelf-item-\(item.id.uuidString)")
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.85) : Color.clear,
                    lineWidth: 1.5
                )
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shelf-item-\(item.id.uuidString)")
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .confirmationDialog(
            L10n.string("Remove “%@” from Shelf?", item.displayName),
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Remove from Shelf"), role: .destructive) { onRemove(item.id) }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This removes references from Shelf only. Original files will not be deleted."))
        }
        .task(id: item.id) {
            thumbnail = await thumbnailService.thumbnail(for: item, size: previewSize)
        }
        .onDisappear {
            thumbnailService.cancelThumbnail(for: item.id)
        }
        .onChange(of: item.status) { _, status in
            if status != .available {
                thumbnail = nil
                thumbnailService.removeCachedThumbnail(for: item.id)
            }
        }
    }

    private var fallbackIcon: NSImage {
        if let url = item.resolvedURL ?? item.fallbackURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let type = item.contentTypeIdentifier.flatMap(UTType.init) ?? .data
        return NSWorkspace.shared.icon(for: type)
    }

    private var fallbackImage: some View {
        let icon = fallbackIcon
        let opacity = item.status == .available ? 0.82 : 0.55
        return Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 42, height: 42)
            .padding(12)
            .opacity(opacity)
    }

    private var statusSymbol: String {
        switch item.status {
        case .available:
            return "checkmark"
        case .missing:
            return "questionmark"
        case .inaccessible:
            return "lock"
        case .staleBookmark, .bookmarkResolutionFailed:
            return "exclamationmark"
        }
    }

    private var statusDescription: String {
        switch item.status {
        case .available:
            return L10n.string("Available")
        case .missing:
            return L10n.string("File not found")
        case .inaccessible:
            return L10n.string("Cannot access file")
        case .staleBookmark:
            return L10n.string("File reference is stale")
        case .bookmarkResolutionFailed:
            return L10n.string("Could not restore file reference")
        }
    }

    private func chooseReplacement() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.string("Use This File")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            onRelocate(item.id, url)
        }
    }
}
