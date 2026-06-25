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
                sourceText: msg.thinkingContent,
                isStreaming: msg.isThinkingInProgress,
                thinkingDurationText: msg.thinkingDurationText
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct ThinkingReasoningSheet: View {
    let sourceText: String
    let isStreaming: Bool
    let thinkingDurationText: String?

    private var titleText: String {
        guard let thinkingDurationText else { return "Thinking complete" }
        return "Thought for \(thinkingDurationText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isStreaming {
                ThinkingShimmerTitle(text: "Thinking")
                    .font(.title3.weight(.semibold))
            } else {
                Text(titleText)
                    .font(.title3.weight(.semibold))
            }
            ScrollView(.vertical, showsIndicators: true) {
                if sourceText.isEmpty {
                    Text("No reasoning available yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(renderedThinkingMarkdown(from: sourceText))
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

private func renderedThinkingMarkdown(from text: String) -> AttributedString {
    let markdownText = thinkingMarkdownReadyText(from: text)
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )
    if let attributed = try? AttributedString(markdown: markdownText, options: options) {
        return applyingNoHyphenationToThinkingText(attributed)
    }
    return applyingNoHyphenationToThinkingText(AttributedString(markdownText))
}

private func thinkingMarkdownReadyText(from text: String) -> String {
    let normalizedText = text
        .replacingOccurrences(of: "\u{00AD}", with: "")
        .replacingOccurrences(of: "/n/n", with: "\n\n")
        .replacingOccurrences(of: "/n", with: "\n")
        .replacingOccurrences(of: "\\n", with: "\n")
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")

    var result = ""
    var newlineRun = 0

    for character in normalizedText {
        if character == "\n" {
            newlineRun += 1
            continue
        }

        if newlineRun == 1 {
            result += "  \n"
        } else if newlineRun > 1 {
            result += String(repeating: "\n", count: newlineRun)
        }
        newlineRun = 0
        result.append(character)
    }

    if newlineRun == 1 {
        result += "  \n"
    } else if newlineRun > 1 {
        result += String(repeating: "\n", count: newlineRun)
    }

    return result
}

private func applyingNoHyphenationToThinkingText(_ attributed: AttributedString) -> AttributedString {
    let nsAttributed = NSAttributedString(attributed)
    let mutable = NSMutableAttributedString(attributedString: nsAttributed)
    let fullRange = NSRange(location: 0, length: mutable.length)

    mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
        let paragraphStyle = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraphStyle.hyphenationFactor = 0
        paragraphStyle.lineBreakMode = .byWordWrapping
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
    }

    return (try? AttributedString(mutable, including: \.uiKit)) ?? attributed
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
