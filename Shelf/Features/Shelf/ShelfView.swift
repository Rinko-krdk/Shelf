//
//  ShelfView.swift
//  Shelf
//

import SwiftUI

struct ShelfView: View {
    @ObservedObject var viewModel: ShelfViewModel

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("Shelf", systemImage: "tray")
                } description: {
                    Text("将文件拖入这里暂存。")
                }
            } else {
                List(viewModel.items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: statusSymbol(for: item.status))
                            .foregroundStyle(statusColor(for: item.status))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .lineLimit(1)
                            Text(statusDescription(for: item.status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("shelf-item-\(item.id.uuidString)")
                }
                .listStyle(.plain)
            }
        }
        .padding(12)
        .accessibilityIdentifier("shelf-empty-state")
    }

    private func statusSymbol(for status: ShelfItemStatus) -> String {
        switch status {
        case .available:
            return "doc"
        case .missing:
            return "questionmark.square"
        case .inaccessible:
            return "lock"
        case .staleBookmark, .bookmarkResolutionFailed:
            return "exclamationmark.triangle"
        }
    }

    private func statusColor(for status: ShelfItemStatus) -> Color {
        status == .available ? .accentColor : .orange
    }

    private func statusDescription(for status: ShelfItemStatus) -> String {
        switch status {
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
}
