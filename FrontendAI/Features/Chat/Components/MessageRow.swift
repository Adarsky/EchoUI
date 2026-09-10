import SwiftUI
import UIKit

struct MessageRow: View {
    @ObservedObject var msg: ChatMessageModel

    let regenerate: (ChatMessageModel) -> Void
    let switchVariant: (UUID, Int) -> Void
    let onEdit: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onBranch: ((UUID) -> Void)?
    let availableWidth: CGFloat
    let botName: String
    @Environment(\.chatAppearance) private var chatAppearance
    @Environment(\.isGenerating) private var isGenerating
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct EditSession: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
    }

    @State private var editSession: EditSession?
    @State private var showDeleteConfirm = false
    @State private var regenerateRotationTurns = 0
    
    @Namespace var MessageRowGlassContainer

    init(
        msg: ChatMessageModel,
        availableWidth: CGFloat = 390,
        botName: String = "Bot",
        regenerate: @escaping (ChatMessageModel) -> Void,
        switchVariant: @escaping (UUID, Int) -> Void,
        onEdit: @escaping (UUID) -> Void = { _ in },
        onDelete: @escaping (UUID) -> Void,
        onBranch: ((UUID) -> Void)? = nil
    ) {
        self.msg = msg
        self.availableWidth = max(1, availableWidth)
        self.botName = botName
        self.regenerate = regenerate
        self.switchVariant = switchVariant
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onBranch = onBranch
    }

    var body: some View {
        HStack(alignment: .top) {
            if msg.isUser { Spacer(minLength: sideSpacerMinLength(for: true)) }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {
                if !msg.isUser, msg.hasThinkingContent {
                    ThinkingField(msg: msg)
                }

                if shouldShowTypingIndicator {
                    TypingIndicator()
                        .padding(12)
                        .background(bubbleFillColor(for: false))
                        .overlay(
                            RoundedRectangle(cornerRadius: bubbleCornerRadius(for: false), style: .continuous)
                                .stroke(bubbleStrokeColor(for: false), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius(for: false), style: .continuous))
                        .frame(maxWidth: maxBubbleWidth(for: false), alignment: .leading)
                } else if !msg.content.isEmpty || msg.isUser {
                    messageText
                        .id(msg.currentIndex)
                        .padding(12)
                        .background(
                            bubbleBackground(for: msg.isUser)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: bubbleCornerRadius(for: msg.isUser), style: .continuous)
                                .stroke(bubbleStrokeColor(for: msg.isUser), lineWidth: 1)
                        )
                        .foregroundStyle(bubbleTextColor(for: msg.isUser))
                        .frame(maxWidth: maxBubbleWidth(for: msg.isUser), alignment: msg.isUser ? .trailing : .leading)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = msg.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            Button {
                                editSession = EditSession(text: msg.content, isUser: msg.isUser)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            if !msg.isUser, let onBranch {
                                Button {
                                    onBranch(msg.id)
                                } label: {
                                    Label("Branch to New Chat", systemImage: "arrow.turn.down.right")
                                }
                                .disabled(isGenerating || msg.isStreaming)
                            }

                            Button(role: .destructive, action: presentDeleteConfirmation) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                if !msg.isUser, let failure = msg.failure {
                    ErrorMessage(
                        failure: failure,
                        isRetryDisabled: isGenerating || msg.isStreaming,
                        retry: retryFailedResponse
                    )
                    .id(failure)
                    .frame(maxWidth: maxBubbleWidth(for: false), alignment: .leading)
                    .transition(ErrorMessage.appearanceTransition(reduceMotion: reduceMotion))
                    .contextMenu {
                        if let onBranch {
                            Button {
                                onBranch(msg.id)
                            } label: {
                                Label("Branch to New Chat", systemImage: "arrow.turn.down.right")
                            }
                            .disabled(isGenerating || msg.isStreaming)
                        }

                        Button(role: .destructive, action: presentDeleteConfirmation) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                if shouldShowAssistantControls {
                    GlassEffectContainer {
                        HStack() {
                            Button(
                                "Previous response",
                                systemImage: "chevron.left",
                                action: showPreviousVariant
                            )
                            .imageScale(.small)
                            .disabled(!msg.hasMultipleVariants)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)

                            Button(
                                "Next response",
                                systemImage: "chevron.right",
                                action: showNextVariant
                            )
                            .imageScale(.medium)
                            .disabled(!msg.hasMultipleVariants)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)

                            if msg.failure == nil {
                                Button(action: regenerateResponse) {
                                    Label("Regenerate response", systemImage: "arrow.clockwise")
                                        .labelStyle(.iconOnly)
                                        .imageScale(.medium)
                                        .rotationEffect(.degrees(Double(regenerateRotationTurns) * 360))
                                }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.circle)
                                .disabled(isGenerating || msg.isStreaming)
                            }

                            Text("\(msg.currentIndex + 1)/\(max(msg.allVariants.count, 1))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                        }
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .padding(.top, 2)
                        .disabled(isGenerating || msg.isStreaming)
                    }
                }
            }
            .frame(maxWidth: .infinity,
                   alignment: msg.isUser ? .trailing : .leading)

            if !msg.isUser { Spacer(minLength: sideSpacerMinLength(for: false)) }
        }
        .animation(.easeOut(duration: 0.15), value: msg.currentIndex)
        .animation(
            ErrorMessage.appearanceAnimation(reduceMotion: reduceMotion),
            value: msg.failure
        )
        .frame(width: availableWidth, alignment: msg.isUser ? .trailing : .leading)
        .sheet(item: $editSession) { session in
            EditMessageSheet(
                text: session.text,
                isUser: session.isUser,
                botName: botName,
                onSave: { newText in
                    msg.replaceCurrentVariant(with: newText)
                    onEdit(msg.id)
                }
            )
        }
        .confirmationDialog(
            "Are you sure?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete(msg.id) }
            Button("Cancel", role: .cancel) { }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(msg.isUser ? "User's message" : "Bot's message")
    }

    private var shouldShowTypingIndicator: Bool {
        !msg.isUser
            && msg.isStreaming
            && msg.content.isEmpty
            && msg.failure == nil
    }

    private var shouldShowAssistantControls: Bool {
        guard !msg.isUser else { return false }
        if msg.failure != nil { return msg.hasMultipleVariants }
        return !msg.content.isEmpty || msg.hasThinkingContent || msg.hasMultipleVariants
    }

    private func showPreviousVariant() {
        switchVariant(msg.id, -1)
    }

    private func showNextVariant() {
        switchVariant(msg.id, 1)
    }

    private func regenerateResponse() {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) {
                regenerateRotationTurns += 1
            }
        }
        regenerate(msg)
    }

    private func retryFailedResponse() {
        regenerate(msg)
    }

    private func presentDeleteConfirmation() {
        showDeleteConfirm = true
    }

    @ViewBuilder
    private var messageText: some View {
        MessageContentView(
            content: msg.content,
            isStreaming: msg.isStreaming,
            fadeInEnabled: chatAppearance.messageTextFadeInEnabled,
            textColor: bubbleTextColor(for: msg.isUser)
        )
    }

    private var userConfiguredColor: Color {
        ChatAppearanceColor.makeColor(
            red: chatAppearance.userBubbleRed,
            green: chatAppearance.userBubbleGreen,
            blue: chatAppearance.userBubbleBlue,
            opacity: chatAppearance.userBubbleOpacity
        )
    }

    private var botConfiguredColor: Color {
        ChatAppearanceColor.makeColor(
            red: chatAppearance.botBubbleRed,
            green: chatAppearance.botBubbleGreen,
            blue: chatAppearance.botBubbleBlue,
            opacity: chatAppearance.botBubbleOpacity
        )
    }

    @ViewBuilder
    private func bubbleBackground(for isUser: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: bubbleCornerRadius(for: isUser), style: .continuous)
        shape.fill(bubbleFillColor(for: isUser))
        if !isBubbleTransparent(for: isUser) {
            ChatMaterialBackground(material: chatAppearance.messageMaterial, shape: shape)
        }
    }

    private func isBubbleTransparent(for isUser: Bool) -> Bool {
        isUser ? chatAppearance.userBubbleTransparent : chatAppearance.botBubbleTransparent
    }

    private func bubbleFillColor(for isUser: Bool) -> Color {
        if isUser {
            return chatAppearance.userBubbleTransparent ? .clear : userConfiguredColor
        }
        return chatAppearance.botBubbleTransparent ? .clear : botConfiguredColor
    }

    private func bubbleStrokeColor(for isUser: Bool) -> Color {
        Color.clear
    }

    private func bubbleCornerRadius(for isUser: Bool) -> CGFloat {
        CGFloat(
            isUser
                ? chatAppearance.clampedUserMessageBubbleCornerRadius
                : chatAppearance.clampedBotMessageBubbleCornerRadius
        )
    }

    private func bubbleTextColor(for isUser: Bool) -> Color {
        let isTransparent = isUser ? chatAppearance.userBubbleTransparent : chatAppearance.botBubbleTransparent
        if isTransparent { return .primary }
        return isUser ? .white : .primary
    }

    private func maxBubbleWidth(for isUser: Bool) -> CGFloat {
        availableWidth * (isUser ? clampedUserMessageBubbleWidthRatio : clampedBotMessageBubbleWidthRatio)
    }

    private func sideSpacerMinLength(for isUser: Bool) -> CGFloat {
        widthRatio(for: isUser) >= 1.0 ? 0 : 40
    }

    private func widthRatio(for isUser: Bool) -> CGFloat {
        isUser ? clampedUserMessageBubbleWidthRatio : clampedBotMessageBubbleWidthRatio
    }

    private var clampedUserMessageBubbleWidthRatio: CGFloat {
        CGFloat(chatAppearance.clampedUserMessageBubbleWidthRatio)
    }

    private var clampedBotMessageBubbleWidthRatio: CGFloat {
        CGFloat(chatAppearance.clampedBotMessageBubbleWidthRatio)
    }
}

private struct MessageContentView: View {
    let content: String
    let isStreaming: Bool
    let fadeInEnabled: Bool
    let textColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let segments = messageContentSegments(from: content)
        let shouldFadeStreamingText = isStreaming && fadeInEnabled && !reduceMotion

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    if shouldFadeStreamingText {
                        StreamingFadeText(text: text, textColor: textColor)
                    } else if isStreaming {
                        Text(verbatim: text)
                    } else {
                        Text(renderedMarkdown(from: text, textColor: textColor))
                    }
                case .divider:
                    Rectangle()
                        .fill(Color.primary.opacity(0.24))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: segments.containsDivider ? .infinity : nil, alignment: .leading)
    }
}

private struct StreamingFadeText: View {
    let text: String
    let textColor: Color

    @State private var stableText = ""
    @State private var fadingText = ""
    @State private var fadeOpacity = 1.0
    @State private var lastText = ""
    @State private var animationGeneration = 0

    private let fadeDuration: TimeInterval = 0.18

    var body: some View {
        displayText
            .onAppear {
                applyText(text)
            }
            .onChange(of: text) { _, newValue in
                applyText(newValue)
            }
    }

    private var displayText: Text {
        if lastText.isEmpty && stableText.isEmpty && fadingText.isEmpty {
            return Text(verbatim: text).foregroundColor(textColor)
        }

        return Text(
            "\(Text(verbatim: stableText).foregroundColor(textColor))\(Text(verbatim: fadingText).foregroundColor(textColor.opacity(fadeOpacity)))"
        )
    }

    private func applyText(_ newText: String) {
        guard newText != lastText else { return }

        animationGeneration += 1
        let generation = animationGeneration
        let previousText = lastText
        lastText = newText

        guard !newText.isEmpty else {
            stableText = ""
            fadingText = ""
            fadeOpacity = 1
            return
        }

        let nextStableText: String
        let nextFadingText: String

        if !previousText.isEmpty, newText.hasPrefix(previousText) {
            nextStableText = previousText
            nextFadingText = String(newText.dropFirst(previousText.count))
        } else {
            nextStableText = ""
            nextFadingText = newText
        }

        guard !nextFadingText.isEmpty else {
            stableText = newText
            fadingText = ""
            fadeOpacity = 1
            return
        }

        stableText = nextStableText
        fadingText = nextFadingText
        fadeOpacity = 0

        withAnimation(.easeOut(duration: fadeDuration)) {
            fadeOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(fadeDuration * 1_000_000_000))
            guard generation == animationGeneration else { return }
            stableText = newText
            fadingText = ""
            fadeOpacity = 1
        }
    }
}

private enum MessageContentSegment {
    case text(String)
    case divider
}

private extension [MessageContentSegment] {
    var containsDivider: Bool {
        contains {
            if case .divider = $0 { return true }
            return false
        }
    }
}

private func messageContentSegments(from text: String) -> [MessageContentSegment] {
    let normalizedText = normalizedMessageText(from: text)
    let lines = normalizedText.split(separator: "\n", omittingEmptySubsequences: false)
    var segments: [MessageContentSegment] = []
    var textLines: [Substring] = []

    func flushTextLines() {
        guard !textLines.isEmpty else { return }
        let joinedText = textLines.joined(separator: "\n")
        if !joinedText.isEmpty {
            segments.append(.text(joinedText))
        }
        textLines.removeAll()
    }

    for line in lines {
        if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            flushTextLines()
            segments.append(.divider)
        } else {
            textLines.append(line)
        }
    }

    flushTextLines()
    return segments.isEmpty ? [.text("")] : segments
}

private func renderedMarkdown(from text: String, textColor: Color) -> AttributedString {
    let markdownText = markdownReadyText(from: text)
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )
    if let attributed = try? AttributedString(markdown: markdownText, options: options) {
        return applyingEmphasisColor(to: applyingNoHyphenation(to: attributed), textColor: textColor)
    }
    return applyingNoHyphenation(to: AttributedString(markdownText))
}

private func markdownReadyText(from text: String) -> String {
    let normalizedText = normalizedMessageText(from: text)

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

private func normalizedMessageText(from text: String) -> String {
    text
        .replacingOccurrences(of: "\u{00AD}", with: "")
        .replacingOccurrences(of: "/n/n", with: "\n\n")
        .replacingOccurrences(of: "/n", with: "\n")
        .replacingOccurrences(of: "\\n", with: "\n")
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
}

private func applyingNoHyphenation(to attributed: AttributedString) -> AttributedString {
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

private func applyingEmphasisColor(to attributed: AttributedString, textColor: Color) -> AttributedString {
    var result = attributed
    let emphasizedRanges = result.runs.compactMap { run -> Range<AttributedString.Index>? in
        guard run.inlinePresentationIntent?.contains(.emphasized) == true else { return nil }
        return run.range
    }

    for range in emphasizedRanges {
        result[range].foregroundColor = textColor.opacity(0.72)
    }

    return result
}

private struct MessageRowPreviewHost: View {
    @StateObject private var message: ChatMessageModel

    init(message: ChatMessageModel) {
        _message = StateObject(wrappedValue: message)
    }

    var body: some View {
        MessageRow(
            msg: message,
            regenerate: { _ in },
            switchVariant: { _, _ in },
            onDelete: { _ in }
        )
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview("Assistant Message") {
    MessageRowPreviewHost(
        message: ChatMessageModel(
            content: "Here is a quick summary of your request.",
            isUser: false
        )
    )
}

#Preview("User Message") {
    MessageRowPreviewHost(
        message: ChatMessageModel(
            content: "Can you add a preview to MessageRow?",
            isUser: true
        )
    )
}

#Preview("Bot Thinking") {
    MessageRowPreviewHost(
        message: ChatMessageModel(
            content: "<think>Reviewing your prompt and outlining the answer structure before responding.</think>Here is the bot response after thinking mode finishes.",
            isUser: false
        )
    )
}

#Preview("Assistant Divider") {
    MessageRowPreviewHost(
        message: ChatMessageModel(
            content: "First section\n---\nSecond section with **Markdown**.",
            isUser: false
        )
    )
}

#Preview("Assistant Blank Line Collapse") {
    MessageRowPreviewHost(
        message: ChatMessageModel(
            content: "First section\n\nSecond section with **Markdown**.",
            isUser: false
        )
    )
}
