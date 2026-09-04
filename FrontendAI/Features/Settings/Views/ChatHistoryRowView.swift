import SwiftUI

struct ChatHistoryRowView: View {
    let history: ChatHistory
    let botName: String
    let depth: Int
    let directBranchCount: Int
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpansion: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            hierarchyControl

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    lastMessagePreview
                        .font(.body)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Text("\(history.messages.count) messages")
                            .foregroundStyle(.gray)
                            .font(.system(.caption, design: .monospaced))

                        if directBranchCount > 0 {
                            Label(
                                "\(directBranchCount) \(directBranchCount == 1 ? "branch" : "branches")",
                                systemImage: "arrow.triangle.branch"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(displayDate.formatted(date: .numeric, time: .shortened))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.leading, CGFloat(min(depth, 4)) * 20)
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var hierarchyControl: some View {
        if directBranchCount > 0 {
            Button(
                isExpanded ? "Collapse branches" : "Expand branches",
                systemImage: isExpanded ? "chevron.down" : "chevron.right",
                action: onToggleExpansion
            )
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
        } else if depth > 0 {
            Image(systemName: "arrow.turn.down.right")
                .foregroundStyle(.tertiary)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        } else {
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var displayDate: Date {
        orderedMessages.last?.timestamp ?? history.date
    }

    private var lastMessagePreview: Text {
        guard let last = orderedMessages.last else {
            return Text("Empty chat")
        }

        let prefix = last.isUser ? "You: " : "\(botName): "
        let previewText = truncatedPreviewText(prefix: prefix, message: last.displayText)
        return Text("\(Text(prefix).fontWeight(.semibold))\(Text(previewText))")
    }

    private var orderedMessages: [ChatMessageEntity] {
        history.messages.sorted { $0.index < $1.index }
    }

    private func truncatedPreviewText(prefix: String, message: String) -> String {
        let maxLength = 80
        let availableMessageLength = max(0, maxLength - prefix.count)
        guard message.count > availableMessageLength else { return message }
        return String(message.prefix(availableMessageLength)) + "…"
    }
}
