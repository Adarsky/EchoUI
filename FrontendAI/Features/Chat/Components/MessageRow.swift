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
        ChatMarkdownView(
            blocks: msg.markdownBlocks,
            fadeNewBlocks: msg.isStreaming && chatAppearance.messageTextFadeInEnabled
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
