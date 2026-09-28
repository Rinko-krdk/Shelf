//
//  ShelfView.swift
//  Shelf
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var viewModel: ShelfViewModel
    @ObservedObject var panelController: ShelfPanelController
    @State private var isDropTargeted = false
    @State private var isConfirmingClear = false
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var selection = ShelfSelectionState()

    init(viewModel: ShelfViewModel, panelController: ShelfPanelController) {
        self.viewModel = viewModel
        self.panelController = panelController
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                FileStackView(
                    items: viewModel.items,
                    selectedIDs: Set(selection.selectedIDs),
                    onSelect: selectItem,
                    onDoubleClick: openItem,
                    onToggleOverflow: toggleOverflow,
                    onPromiseCompleted: completePromise,
                    onDragRejected: { viewModel.reportTransferError($0) }
                )
                .frame(width: 102, height: 72)

                if isHovering {
                    VStack(spacing: 7) {
                        Button { isConfirmingClear = true } label: {
                            Image(systemName: "trash")
                        }
                        .help("清空 Shelf")
                        .accessibilityLabel("清空 Shelf")
                        .accessibilityIdentifier("shelf-clear-button")
                        .disabled(viewModel.items.isEmpty)

                        Button { panelController.hide() } label: {
                            Image(systemName: "xmark")
                        }
                        .help("隐藏并清空 Shelf")
                        .accessibilityLabel("隐藏并清空 Shelf")
                        .accessibilityIdentifier("shelf-hide-button")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 22)
                    .transition(.opacity)
                } else {
                    Color.clear.frame(width: 22)
                }
            }
            .frame(width: 148, height: 92)

            if isExpanded {
                FileStackListView(
                    items: viewModel.items,
                    selectedIDs: Set(selection.selectedIDs),
                    onSelect: selectItem,
                    onDoubleClick: openItem,
                    onPromiseCompleted: completePromise,
                    onDragRejected: { viewModel.reportTransferError($0) }
                )
                .frame(width: 140, height: expandedListHeight)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 148, height: contentHeight, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.22), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .accessibilityIdentifier("shelf-content-panel")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
            if hovering { panelController.beginInteraction() }
            else { panelController.endInteraction() }
        }
        .onDrop(
            of: [UTType.fileURL, UTType.url],
            isTargeted: $isDropTargeted,
            perform: handleDrop
        )
        .onChange(of: isDropTargeted) { _, targeted in
            if targeted { panelController.beginInteraction() }
            else { panelController.endInteraction() }
        }
        .onChange(of: isExpanded) { _, expanded in
            panelController.setExpanded(
                expanded,
                listHeight: expanded ? expandedListHeight : 0
            )
        }
        .onChange(of: viewModel.items.map(\.id)) { _, ids in
            selection.retain(Set(ids))
            if ids.count <= FileStackPresentation.maximumVisibleIcons, isExpanded {
                isExpanded = false
            } else if isExpanded {
                panelController.setExpanded(true, listHeight: expandedListHeight)
            }
        }
        .onChange(of: panelController.isVisible) { _, visible in
            if !visible {
                selection.clear()
                isExpanded = false
            }
        }
        .onChange(of: viewModel.items.isEmpty) { wasEmpty, isEmpty in
            if !wasEmpty && isEmpty { panelController.hideIfEmptyImmediately() }
        }
        .contextMenu {
            if !viewModel.items.isEmpty {
                Button("清空 Shelf", role: .destructive) { isConfirmingClear = true }
            }
        }
        .confirmationDialog(
            "清空 Shelf？",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("清空 Shelf", role: .destructive) {
                viewModel.removeAll()
                panelController.hideIfEmptyImmediately()
            }
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

    private func completePromise(_ id: ShelfItem.ID, _ error: Error?) {
        guard let error else {
            viewModel.completeTransfer(ids: [id], result: .moved)
            panelController.hideIfEmptyImmediately()
            return
        }
        viewModel.reportTransferError("\(viewModel.items.first(where: { $0.id == id })?.displayName ?? "所选项目")未能放置：\(error.localizedDescription)")
    }

    private var orderedIDs: [ShelfItem.ID] { viewModel.items.map(\.id) }

    private var expandedListHeight: CGFloat {
        FileStackListView.height(for: viewModel.items.count)
    }

    private var contentHeight: CGFloat {
        92 + (isExpanded ? 6 + expandedListHeight : 0)
    }

    private func selectItem(_ id: ShelfItem.ID, _ modifiers: NSEvent.ModifierFlags) {
        selection.select(
            id,
            command: modifiers.contains(.command),
            shift: modifiers.contains(.shift),
            orderedIDs: orderedIDs
        )
    }

    private func toggleOverflow() {
        guard viewModel.items.count > FileStackPresentation.maximumVisibleIcons else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isExpanded.toggle()
        }
    }

    private func openItem(_ id: ShelfItem.ID) {
        guard let item = viewModel.items.first(where: { $0.id == id }),
              item.status == .available,
              let url = item.resolvedURL,
              url.isFileURL else {
            viewModel.reportTransferError("该文件当前不可用，无法打开。")
            return
        }

        let startedAccessing = url.startAccessingSecurityScopedResource()
        let opened = NSWorkspace.shared.open(url)
        if startedAccessing { url.stopAccessingSecurityScopedResource() }
        if !opened {
            viewModel.reportTransferError("无法打开文件：\(item.displayName)。请检查文件访问权限。")
        }
    }

}
