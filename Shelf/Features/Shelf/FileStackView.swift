//
//  FileStackView.swift
//  Shelf
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileStackPresentation: Equatable {
    static let maximumVisibleIcons = 3

    let visibleIconCount: Int
    let hiddenItemCount: Int

    init(itemCount: Int) {
        visibleIconCount = min(max(0, itemCount), Self.maximumVisibleIcons)
        hiddenItemCount = max(0, itemCount - Self.maximumVisibleIcons)
    }

    var badgeText: String? {
        hiddenItemCount > 0 ? "+\(hiddenItemCount)" : nil
    }
}

struct FileStackView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    let items: [ShelfItem]
    let selectedIDs: Set<ShelfItem.ID>
    let onSelect: (ShelfItem.ID, NSEvent.ModifierFlags) -> Void
    let onDoubleClick: (ShelfItem.ID) -> Void
    let onToggleOverflow: () -> Void
    let onPromiseCompleted: (ShelfItem.ID, Error?) -> Void
    let onDragRejected: (String) -> Void

    private var presentation: FileStackPresentation { FileStackPresentation(itemCount: items.count) }
    private var selectedItems: [ShelfItem] { items.filter { selectedIDs.contains($0.id) } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(items.prefix(FileStackPresentation.maximumVisibleIcons).enumerated()), id: \.element.id) { index, item in
                iconCard(item, index: index)
                    .offset(x: CGFloat(index) * 23, y: CGFloat(index) * 1.5)
                    .zIndex(Double(FileStackPresentation.maximumVisibleIcons - index))
            }

            if items.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 23, weight: .regular))
                    Text(L10n.string("Drop files here"))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(width: 68, height: 62)
                .frame(width: 102, height: 72)
                .accessibilityLabel(L10n.string("Empty Shelf. Drop files here to stage them."))
            }

            if let badgeText = presentation.badgeText {
                Button(action: onToggleOverflow) {
                    HStack(spacing: 3) {
                        Text(badgeText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.background, in: Capsule())
                    .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(presentation.hiddenItemCount == 1 ? L10n.string("Show one more file") : L10n.string("Show %d more files", presentation.hiddenItemCount))
                .accessibilityLabel(presentation.hiddenItemCount == 1 ? L10n.string("Show one more file") : L10n.string("Show %d more files", presentation.hiddenItemCount))
                .accessibilityIdentifier("shelf-overflow-toggle")
                .offset(x: 72, y: -3)
                .zIndex(10)
            }
        }
        .frame(width: 102, height: 72)
        .accessibilityLabel(items.isEmpty ? L10n.string("Empty Shelf") : (items.count == 1 ? L10n.string("One staged file") : L10n.string("%d staged files", items.count)))
        .accessibilityIdentifier("shelf-file-stack")
    }

    private func iconCard(_ item: ShelfItem, index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.regularMaterial)
            Image(nsImage: icon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 48)
                .padding(7)
                .opacity(item.status == .available ? 1 : 0.55)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    selectedIDs.contains(item.id) ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: selectedIDs.contains(item.id) ? 2 : 1
                )
                .allowsHitTesting(false)

            ShelfDragSourceView(
                item: item,
                itemID: item.id,
                selectedItems: selectedItems,
                isSelected: selectedIDs.contains(item.id),
                onSelect: onSelect,
                onDoubleClick: onDoubleClick,
                onPromiseCompleted: onPromiseCompleted,
                onDragRejected: onDragRejected,
                accessibilityIdentifier: "shelf-stack-item-\(item.id.uuidString)"
            )
            .frame(width: 56, height: 62)
        }
        .frame(width: 56, height: 62)
        .rotationEffect(.degrees(Double(index) * 3 - 3))
        .help(item.displayName)
    }

    private func icon(for item: ShelfItem) -> NSImage {
        guard let url = item.resolvedURL ?? item.fallbackURL else {
            return NSWorkspace.shared.icon(for: .data)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct FileStackListView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredItemID: ShelfItem.ID?
    static let rowHeight: CGFloat = 36
    static let maximumHeight: CGFloat = 180

    let items: [ShelfItem]
    let selectedIDs: Set<ShelfItem.ID>
    let onSelect: (ShelfItem.ID, NSEvent.ModifierFlags) -> Void
    let onDoubleClick: (ShelfItem.ID) -> Void
    let onPromiseCompleted: (ShelfItem.ID, Error?) -> Void
    let onDragRejected: (String) -> Void

    static func height(for itemCount: Int) -> CGFloat {
        min(CGFloat(itemCount) * rowHeight, maximumHeight)
    }

    private var selectedItems: [ShelfItem] { items.filter { selectedIDs.contains($0.id) } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(items) { item in
                    fileRow(item)
                }
            }
            .padding(4)
        }
        .frame(height: Self.height(for: items.count))
        .accessibilityIdentifier("shelf-expanded-file-list")
    }

    private func fileRow(_ item: ShelfItem) -> some View {
        ZStack {
            HStack(spacing: 8) {
                Image(nsImage: icon(for: item))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .opacity(item.status == .available ? 1 : 0.55)
                Text(item.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 2)
                if selectedIDs.contains(item.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                }
                if item.status != .available {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: Self.rowHeight - 2)
            .background(
                selectedIDs.contains(item.id)
                    ? Color.accentColor.opacity(0.12)
                    : (hoveredItemID == item.id ? Color.primary.opacity(0.055) : Color.clear),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(selectedIDs.contains(item.id) ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
                    .allowsHitTesting(false)
            }

            ShelfDragSourceView(
                item: item,
                itemID: item.id,
                selectedItems: selectedItems,
                isSelected: selectedIDs.contains(item.id),
                onSelect: onSelect,
                onDoubleClick: onDoubleClick,
                onPromiseCompleted: onPromiseCompleted,
                onDragRejected: onDragRejected,
                accessibilityIdentifier: "shelf-expanded-file-row-\(item.id.uuidString)"
            )
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight - 2)
        }
        .frame(height: Self.rowHeight - 2)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                if hovering {
                    hoveredItemID = item.id
                } else if hoveredItemID == item.id {
                    hoveredItemID = nil
                }
            }
        }
    }

    private func icon(for item: ShelfItem) -> NSImage {
        guard let url = item.resolvedURL ?? item.fallbackURL else {
            return NSWorkspace.shared.icon(for: .data)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
