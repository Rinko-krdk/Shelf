//
//  ShelfView.swift
//  Shelf
//

import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var viewModel: ShelfViewModel
    @StateObject private var thumbnailService = ThumbnailService()
    @State private var isDropTargeted = false
    @State private var isConfirmingClear = false
    @State private var selection = ShelfSelectionState()

    private let columns = [GridItem(.adaptive(minimum: 112, maximum: 150), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Shelf · \(viewModel.items.count)")
                    .font(.headline)
                if !selection.selectedIDs.isEmpty {
                    Text("已选 \(selection.selectedIDs.count) 项 · 拖出即剪切")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("清空") { isConfirmingClear = true }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.items.isEmpty)
                    .accessibilityIdentifier("clear-shelf-button")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("Shelf", systemImage: "tray")
                } description: {
                    Text("将文件拖入这里暂存。")
                }
                .accessibilityIdentifier("shelf-empty-state")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(viewModel.items) { item in
                            ShelfItemCard(
                                item: item,
                                thumbnailService: thumbnailService,
                                isSelected: selection.selectedIDs.contains(item.id),
                                selectedItems: selectedItems,
                                onSelect: selectItem,
                                onPromiseCompleted: completePromise,
                                onNeedsWriteAccess: authorizeWriteAccess,
                                onRemove: viewModel.remove(id:),
                                onRelocate: viewModel.reselect(id:with:)
                            )
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("shelf-item-grid")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.clear,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                }
                .padding(3)
                .allowsHitTesting(false)
        }
        .onDrop(
            of: [UTType.fileURL, UTType.url],
            isTargeted: $isDropTargeted,
            perform: handleDrop
        )
        .onChange(of: viewModel.items.map(\.id)) { _, itemIDs in
            thumbnailService.retainThumbnails(for: Set(itemIDs))
            selection.retain(Set(itemIDs))
        }
        .confirmationDialog(
            "清空 Shelf？",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("清空 Shelf", role: .destructive) { viewModel.removeAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会移除 Shelf 中的引用，不会删除原文件。")
        }
        .alert("Shelf 提示", isPresented: Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("好") { viewModel.clearError() }
        } message: {
            Text(viewModel.lastError?.localizedDescription ?? "发生了未知错误。")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        Task { @MainActor in
            let urls = await ShelfDropImporter.loadFileURLs(from: providers)
            guard !urls.isEmpty else { return }
            viewModel.add(urls: urls)
        }
        return true
    }

    private var selectedItems: [ShelfItem] {
        let selectedIDs = Set(selection.selectedIDs)
        return viewModel.items.filter { selectedIDs.contains($0.id) }
    }

    private func selectItem(_ id: ShelfItem.ID, _ modifiers: NSEvent.ModifierFlags) {
        selection.select(
            id,
            command: modifiers.contains(.command),
            shift: modifiers.contains(.shift),
            orderedIDs: viewModel.items.map(\.id)
        )
    }

    private func completePromise(_ id: ShelfItem.ID, _ error: Error?) {
        guard let error else {
            viewModel.completeTransfer(ids: [id], result: .moved)
            selection.retain(Set(viewModel.items.map(\.id)))
            return
        }
        viewModel.reportTransferError("\(viewModel.items.first(where: { $0.id == id })?.displayName ?? "所选项目")未能放置：\(error.localizedDescription)")
    }

    private func authorizeWriteAccess(for ids: [ShelfItem.ID]) {
        let idSet = Set(ids)
        let itemsNeedingWriteAccess = viewModel.items.filter {
            idSet.contains($0.id) && !$0.bookmarkAllowsWriteAccess
        }
        guard !itemsNeedingWriteAccess.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.title = "授权剪切所选文件"
        panel.message = "重新选择 Shelf 中的同一批文件，以授权剪切时删除源文件。"
        panel.prompt = "授权剪切"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK else { return }
            let selectedPaths = Set(panel.urls.map { $0.standardizedFileURL.path })
            let authorizedURLByPath = Dictionary(
                uniqueKeysWithValues: panel.urls.map { ($0.standardizedFileURL.path, $0) }
            )
            let requiredPaths = itemsNeedingWriteAccess.compactMap { $0.resolvedURL?.standardizedFileURL.path }
            guard requiredPaths.count == itemsNeedingWriteAccess.count,
                  requiredPaths.allSatisfy(selectedPaths.contains) else {
                viewModel.reportTransferError("请选择与 Shelf 中选中项完全相同的文件；没有执行剪切。")
                return
            }

            for item in itemsNeedingWriteAccess {
                guard let path = item.resolvedURL?.standardizedFileURL.path,
                      let url = authorizedURLByPath[path] else { continue }
                viewModel.reselect(id: item.id, with: url)
            }
            let reauthorizedIDs = Set(itemsNeedingWriteAccess.map(\.id))
            let reauthorizedItems = viewModel.items.filter { reauthorizedIDs.contains($0.id) }
            guard reauthorizedItems.count == reauthorizedIDs.count,
                  reauthorizedItems.allSatisfy(\.bookmarkAllowsWriteAccess) else {
                viewModel.reportTransferError("无法取得所选文件的写入授权；没有执行剪切。")
                return
            }
        }
    }
}
