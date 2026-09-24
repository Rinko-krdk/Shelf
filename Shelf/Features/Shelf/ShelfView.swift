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

    private let columns = [GridItem(.adaptive(minimum: 112, maximum: 150), spacing: 12)]

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("Shelf", systemImage: "tray")
                } description: {
                    Text("将文件拖入这里暂存。")
                }
                .accessibilityIdentifier("shelf-empty-state")
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Shelf · \(viewModel.items.count)")
                            .font(.headline)
                        Spacer()
                        Button("清空") { isConfirmingClear = true }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("clear-shelf-button")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(viewModel.items) { item in
                                ShelfItemCard(
                                    item: item,
                                    thumbnailService: thumbnailService,
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
}
