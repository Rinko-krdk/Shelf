//
//  ShelfItemCard.swift
//  Shelf
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfItemCard: View {
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
                .help("从 Shelf 移除")
                .accessibilityLabel("移除 \(item.displayName)")
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
                    Label("重新选择…", systemImage: "arrow.triangle.2.circlepath")
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
            "从 Shelf 移除“\(item.displayName)”？",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("从 Shelf 移除", role: .destructive) { onRemove(item.id) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会移除 Shelf 中的引用，不会删除原文件。")
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
            return "可用"
        case .missing:
            return "文件不存在"
        case .inaccessible:
            return "无法访问"
        case .staleBookmark:
            return "文件引用已失效"
        case .bookmarkResolutionFailed:
            return "无法恢复文件引用"
        }
    }

    private func chooseReplacement() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "使用此文件"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            onRelocate(item.id, url)
        }
    }
}
