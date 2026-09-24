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
    let onNeedsWriteAccess: ([ShelfItem.ID]) -> Void
    let onRemove: (ShelfItem.ID) -> Void
    let onRelocate: (ShelfItem.ID, URL) -> Void

    @State private var thumbnail: NSImage?
    @State private var isConfirmingRemoval = false

    private let previewSize = CGSize(width: 112, height: 82)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(5)
                } else {
                    Image(nsImage: fallbackIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(18)
                        .foregroundStyle(item.status == .available ? Color(nsColor: .secondaryLabelColor) : .orange)
                }

                ShelfDragSourceView(
                    item: item,
                    itemID: item.id,
                    selectedItems: selectedItems,
                    onSelect: onSelect,
                    onPromiseCompleted: onPromiseCompleted,
                    onNeedsWriteAccess: onNeedsWriteAccess
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
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.62))
                }
                .buttonStyle(.plain)
                .help("从 Shelf 移除")
                .accessibilityLabel("移除 \(item.displayName)")
                .accessibilityIdentifier("remove-shelf-item-\(item.id.uuidString)")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(5)
            }
            .frame(height: previewSize.height)

            Text(item.displayName)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .help(item.displayName)
                .accessibilityLabel(item.displayName)
                .onTapGesture {
                    onSelect(item.id, NSEvent.modifierFlags)
                }

            if item.status != .available {
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusDescription)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                    Button("重新选择…", action: chooseReplacement)
                        .font(.caption2)
                        .buttonStyle(.link)
                        .accessibilityIdentifier("reselect-shelf-item-\(item.id.uuidString)")
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.35),
                    lineWidth: isSelected ? 2 : 1
                )
        }
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
