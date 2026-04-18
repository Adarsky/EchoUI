import SwiftUI

struct ThinkingField: View {
    @ObservedObject var msg: ChatMessageModel
    @State private var isSheetPresented = false

    var body: some View {
        Button {
            isSheetPresented = true
        } label: {
            HStack(spacing: 6) {
                Text(msg.thinkingStatusText)
                    .font(.footnote.weight(.semibold))

                Image(systemName: "chevron.up.forward")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.glass)
        .onChange(of: msg.currentIndex) { _, _ in
            isSheetPresented = false
        }
        .sheet(isPresented: $isSheetPresented) {
            ThinkingReasoningSheet(
                sourceText: msg.thinkingContent,
                isStreaming: msg.isThinkingInProgress
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct ThinkingReasoningSheet: View {
    let sourceText: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(isStreaming ? "Reasoning (in progress)" : "Reasoning")
                    .font(.headline.weight(.semibold))
                if isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(sourceText.isEmpty ? "No reasoning available yet." : sourceText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding()
    }
}

private struct ThinkingFieldPreviewHost: View {
    @StateObject private var message: ChatMessageModel

    init(message: ChatMessageModel) {
        _message = StateObject(wrappedValue: message)
    }

    var body: some View {
        ThinkingField(msg: message)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
    }
}

#Preview("Thinking In Progress") {
    ThinkingFieldPreviewHost(
        message: ChatMessageModel(
            content: "<think>Analyzing your input and checking constraints while I prepare the response.",
            isUser: false
        )
    )
}

#Preview("Thinking Completed") {
    ThinkingFieldPreviewHost(
        message: ChatMessageModel(
            content: "<think>Collected relevant context, then drafted a concise result.</think>Here is the final assistant message.",
            isUser: false
        )
    )
}
