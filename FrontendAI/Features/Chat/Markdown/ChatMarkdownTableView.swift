import SwiftUI

struct ChatMarkdownTableView: View {
    let rows: [ChatMarkdownBlock]
    let columns: [PresentationIntent.TableColumn]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(rows) { row in
                    GridRow {
                        ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                            // Foundation omits empty cells; preserve their column positions.
                            ChatMarkdownInlineView(parts: cell(in: row, column: index)?.parts ?? [])
                                .fontWeight(row.kind == .tableHeaderRow ? .semibold : .regular)
                                .padding(8)
                                .frame(minWidth: 70, maxWidth: 260, alignment: alignment(column))
                                .gridColumnAlignment(horizontalAlignment(column))
                                .background(.primary.opacity(row.kind == .tableHeaderRow ? 0.09 : 0.03))
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(.primary.opacity(0.12)).frame(height: 0.5)
                                }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table")
    }

    private func cell(in row: ChatMarkdownBlock, column: Int) -> ChatMarkdownBlock? {
        row.children.first { $0.kind == .tableCell(columnIndex: column) }
    }

    private func alignment(_ column: PresentationIntent.TableColumn) -> Alignment {
        switch column.alignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        @unknown default: .leading
        }
    }

    private func horizontalAlignment(_ column: PresentationIntent.TableColumn) -> HorizontalAlignment {
        switch column.alignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        @unknown default: .leading
        }
    }
}
