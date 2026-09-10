import SwiftUI

struct ChatMarkdownBlockView: View, Equatable {
    let block: ChatMarkdownBlock
    var orderedList = false

    var body: some View {
        switch block.kind {
        case .paragraph, .tableCell:
            ChatMarkdownInlineView(parts: block.parts)
        case .header(let level):
            ChatMarkdownInlineView(parts: block.parts)
                .font(headingFont(level))
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
        case .codeBlock(let language):
            ChatMarkdownCodeView(code: String(block.text.characters), language: language)
        case .thematicBreak:
            Rectangle()
                .fill(.primary.opacity(0.24))
                .frame(height: 1)
                .padding(.vertical, 4)
                .accessibilityHidden(true)
        case .blockQuote:
            children
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.secondary.opacity(0.4)).frame(width: 3)
                }
        case .orderedList, .unorderedList:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(block.children) { child in
                    ChatMarkdownBlockView(block: child, orderedList: block.kind == .orderedList)
                        .equatable()
                }
            }
        case .listItem(let ordinal):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let checked = block.taskChecked {
                    Image(systemName: checked ? "checkmark.square" : "square")
                        .accessibilityLabel(checked ? "Completed" : "Not completed")
                } else {
                    Text(orderedList ? "\(ordinal)." : "•")
                        .monospacedDigit()
                        .accessibilityHidden(!orderedList)
                }
                children
            }
        case .table(let columns):
            ChatMarkdownTableView(rows: block.children, columns: columns)
        case .tableHeaderRow, .tableRow:
            children
        @unknown default:
            ChatMarkdownInlineView(parts: block.parts)
        }
    }

    private var children: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(block.children) { child in
                ChatMarkdownBlockView(block: child).equatable()
            }
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
        }
    }
}
