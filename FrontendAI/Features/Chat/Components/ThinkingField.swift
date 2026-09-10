import SwiftUI
import UIKit

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

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.glass)
        .onChange(of: msg.currentIndex) { _, _ in
            isSheetPresented = false
        }
        .sheet(isPresented: $isSheetPresented) {
            ThinkingReasoningSheet(
                msg: msg
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct ThinkingReasoningSheet: View {
    @ObservedObject var msg: ChatMessageModel

    private var titleText: String {
        guard let thinkingDurationText = msg.thinkingDurationText else { return "Thinking complete" }
        return "Thought for \(thinkingDurationText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if msg.isThinkingInProgress {
                ThinkingShimmerTitle(text: "Thinking")
                    .font(.title3.weight(.semibold))
            } else {
                Text(titleText)
                    .font(.title3.weight(.semibold))
            }
            ScrollView(.vertical, showsIndicators: true) {
                if msg.thinkingContent.isEmpty {
                    Text("No reasoning available yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ChatMarkdownView(blocks: msg.thinkingMarkdownBlocks)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .padding()
    }
}

private struct ThinkingShimmerTitle: View {
    let text: String
    @State private var opacity: CGFloat = 0.58

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .opacity(opacity)
            .onAppear {
                opacity = 0.58
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    opacity = 1
                }
            }
            .onDisappear {
                opacity = 0.58
            }
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
