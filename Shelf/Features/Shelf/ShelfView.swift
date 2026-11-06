//
//  ShelfView.swift
//  Shelf
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ShelfLayout {
    static let contentWidth: CGFloat = 164
    static let compactStackWidth: CGFloat = 102
    static let expandedListWidth: CGFloat = 156
    static let contentHeight: CGFloat = 92
}

struct ShelfView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            HStack(spacing: 24) {
                FileStackView(
                    items: viewModel.items,
                    selectedIDs: Set(selection.selectedIDs),
                    onSelect: selectItem,
                    onDoubleClick: openItem,
                    onToggleOverflow: toggleOverflow,
                    onPromiseCompleted: completePromise,
                    onDragRejected: { viewModel.reportTransferError($0) }
                )
                .frame(width: ShelfLayout.compactStackWidth, height: 72)

                if isHovering {
                    VStack(spacing: 4) {
                        Button(action: selectAllItems) {
                            Image(systemName: areAllItemsSelected ? "circle.slash" : "checkmark.circle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .help(selectionButtonLabel)
                        .accessibilityLabel(selectionButtonLabel)
                        .accessibilityIdentifier("shelf-select-all-button")
                        .disabled(viewModel.items.isEmpty)

                        Button { isConfirmingClear = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .help(L10n.string("Clear Shelf"))
                        .accessibilityLabel(L10n.string("Clear Shelf"))
                        .accessibilityIdentifier("shelf-clear-button")
                        .disabled(viewModel.items.isEmpty)

                        Button { panelController.hide() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .help(L10n.string("Hide and clear Shelf"))
                        .accessibilityLabel(L10n.string("Hide and clear Shelf"))
                        .accessibilityIdentifier("shelf-hide-button")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .trailing)))
                } else {
                    Color.clear.frame(width: 28)
                }
            }
            .frame(width: ShelfLayout.contentWidth, height: ShelfLayout.contentHeight)

            if isExpanded {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 4)

                FileStackListView(
                    items: viewModel.items,
                    selectedIDs: Set(selection.selectedIDs),
                    onSelect: selectItem,
                    onSweepSelection: { selection.add($0, orderedIDs: orderedIDs) },
                    onDoubleClick: openItem,
                    onPromiseCompleted: completePromise,
                    onDragRejected: { viewModel.reportTransferError($0) }
                )
                .frame(width: ShelfLayout.expandedListWidth, height: expandedListHeight)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: ShelfLayout.contentWidth, height: contentHeight, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shelf-content-panel")
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { isHovering = hovering }
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
                Button(L10n.string("Clear Shelf"), role: .destructive) { isConfirmingClear = true }
            }
        }
        .confirmationDialog(
            L10n.string("Clear Shelf?"),
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Clear Shelf"), role: .destructive) {
                viewModel.removeAll()
                panelController.hideIfEmptyImmediately()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This removes references from Shelf only. Original files will not be deleted."))
        }
        .alert(L10n.string("Shelf Notice"), isPresented: Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button(L10n.string("OK")) { viewModel.clearError() }
        } message: {
            Text(viewModel.lastError?.localizedDescription ?? L10n.string("An unknown error occurred."))
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
        viewModel.reportTransferError(L10n.string("%@ could not be placed: %@", viewModel.items.first(where: { $0.id == id })?.displayName ?? L10n.string("Selected item"), error.localizedDescription))
    }

    private var orderedIDs: [ShelfItem.ID] { viewModel.items.map(\.id) }

    private var expandedListHeight: CGFloat {
        FileStackListView.height(for: viewModel.items.count)
    }

    private var areAllItemsSelected: Bool {
        !viewModel.items.isEmpty && selection.selectedIDs.count == viewModel.items.count
    }

    private var selectionButtonLabel: String {
        L10n.string(areAllItemsSelected ? "Deselect All" : "Select All")
    }

    private var contentHeight: CGFloat {
        92 + (isExpanded ? 13 + expandedListHeight : 0)
    }

    private func selectItem(_ id: ShelfItem.ID, _ modifiers: NSEvent.ModifierFlags) {
        selection.select(
            id,
            command: modifiers.contains(.command),
            shift: modifiers.contains(.shift),
            orderedIDs: orderedIDs
        )
    }

    private func selectAllItems() {
        if areAllItemsSelected {
            selection.clear()
        } else {
            selection.replace(with: Set(orderedIDs), orderedIDs: orderedIDs)
        }
    }

    private func toggleOverflow() {
        guard viewModel.items.count > FileStackPresentation.maximumVisibleIcons else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)) {
            isExpanded.toggle()
        }
    }

    private func openItem(_ id: ShelfItem.ID) {
        viewModel.openItem(id: id) { NSWorkspace.shared.open($0) }
    }

}
