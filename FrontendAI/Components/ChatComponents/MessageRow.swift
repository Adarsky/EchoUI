//
//  MessageRow.swift
//  FrontendAI
//
//  Created by macbook on 30.03.2025.
//  Последнее изменение: 04.07.2025 – добавлен .id(msg.currentIndex)
//

import SwiftUI
import UIKit

struct MessageRow: View {
    @ObservedObject var msg: ChatMessageModel

    let regenerate: (ChatMessageModel) -> Void
    let switchVariant: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void

    private struct EditSession: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
    }

    @AppStorage(ChatAppearanceStorageKeys.userBubbleRed) private var userBubbleRed = ChatAppearanceDefaults.userBubbleRed
    @AppStorage(ChatAppearanceStorageKeys.userBubbleGreen) private var userBubbleGreen = ChatAppearanceDefaults.userBubbleGreen
    @AppStorage(ChatAppearanceStorageKeys.userBubbleBlue) private var userBubbleBlue = ChatAppearanceDefaults.userBubbleBlue
    @AppStorage(ChatAppearanceStorageKeys.userBubbleOpacity) private var userBubbleOpacity = ChatAppearanceDefaults.userBubbleOpacity
    @AppStorage(ChatAppearanceStorageKeys.userBubbleTransparent) private var userBubbleTransparent = ChatAppearanceDefaults.userBubbleTransparent

    @AppStorage(ChatAppearanceStorageKeys.botBubbleRed) private var botBubbleRed = ChatAppearanceDefaults.botBubbleRed
    @AppStorage(ChatAppearanceStorageKeys.botBubbleGreen) private var botBubbleGreen = ChatAppearanceDefaults.botBubbleGreen
    @AppStorage(ChatAppearanceStorageKeys.botBubbleBlue) private var botBubbleBlue = ChatAppearanceDefaults.botBubbleBlue
    @AppStorage(ChatAppearanceStorageKeys.botBubbleOpacity) private var botBubbleOpacity = ChatAppearanceDefaults.botBubbleOpacity
    @AppStorage(ChatAppearanceStorageKeys.botBubbleTransparent) private var botBubbleTransparent = ChatAppearanceDefaults.botBubbleTransparent
    @AppStorage(ChatAppearanceStorageKeys.userMessageBubbleWidthRatio) private var userMessageBubbleWidthRatio = ChatAppearanceDefaults.userMessageBubbleWidthRatio
    @AppStorage(ChatAppearanceStorageKeys.botMessageBubbleWidthRatio) private var botMessageBubbleWidthRatio = ChatAppearanceDefaults.botMessageBubbleWidthRatio

    @State private var editSession: EditSession?
    @State private var showDeleteConfirm = false
    @State private var availableWidth: CGFloat = 0
    
    @Namespace var MessageRowGlassContainer

    var body: some View {
        HStack(alignment: .top) {
            if msg.isUser { Spacer(minLength: sideSpacerMinLength(for: true)) }

            LazyVStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {
                if !msg.isUser, msg.hasThinkingContent {
                    ThinkingField(msg: msg)
                }

                if msg.content.isEmpty && !msg.isUser {
                    TypingIndicator()
                        .padding(12)
                        .background(bubbleFillColor(for: false))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(bubbleStrokeColor(for: false), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: maxBubbleWidth(for: false), alignment: .leading)
                } else {
                    Text(msg.isStreaming ? AttributedString(msg.content) : renderedMarkdown(from: msg.content))
                        .id(msg.currentIndex)
                        .padding(12)
                        .background(
                            bubbleBackground(for: msg.isUser)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(bubbleStrokeColor(for: msg.isUser), lineWidth: 1)
                        )
                        .foregroundColor(bubbleTextColor(for: msg.isUser))
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

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .confirmationDialog(
                            "Are you surе?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) { onDelete(msg.id) }
                            Button("Cancel", role: .cancel) { }
                        }
                }

                if !msg.isUser {
                    GlassEffectContainer() {
                        HStack(spacing: 16) {
                            // PREV
                            Button {
                                switchVariant(msg.id, -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .imageScale(.medium)
                            }
                            .disabled(!msg.hasMultipleVariants)
                            .buttonStyle(.glass)
                            .glassEffectUnion(id: 1, namespace: MessageRowGlassContainer)
                            
                            Button {
                                switchVariant(msg.id, +1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .imageScale(.medium)
                            }
                            .disabled(!msg.hasMultipleVariants)
                            .buttonStyle(.glass)
                            .glassEffectUnion(id: 1, namespace: MessageRowGlassContainer)
                            
                            // REGENERATE
                            Button {
                                regenerate(msg)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.glass)
                            .glassEffectUnion(id: 2, namespace: MessageRowGlassContainer)
                            
                            // NEXT
                            
                            Text("\(msg.currentIndex + 1)/\(max(msg.allVariants.count, 1))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                        }
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity,
                   alignment: msg.isUser ? .trailing : .leading)

            if !msg.isUser { Spacer(minLength: sideSpacerMinLength(for: false)) }
        }

        .animation(.easeOut(duration: 0.15), value: msg.currentIndex)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        availableWidth = proxy.size.width
                    }
                    .onChange(of: proxy.size.width) { _, newValue in
                        availableWidth = newValue
                    }
            }
        }
        .sheet(item: $editSession) { session in
            LegacyEditMessageSheet(
                text: session.text,
                isUser: session.isUser,
                onSave: { newText in
                    Task { @MainActor in
                        msg.replaceCurrentVariant(with: newText)
                    }
                }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(msg.isUser ? "User's message" : "Bot's message")
    }

    private var userConfiguredColor: Color {
        ChatAppearanceColor.makeColor(
            red: userBubbleRed,
            green: userBubbleGreen,
            blue: userBubbleBlue,
            opacity: userBubbleOpacity
        )
    }

    private var botConfiguredColor: Color {
        ChatAppearanceColor.makeColor(
            red: botBubbleRed,
            green: botBubbleGreen,
            blue: botBubbleBlue,
            opacity: botBubbleOpacity
        )
    }

    @ViewBuilder
    private func bubbleBackground(for isUser: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape.fill(bubbleFillColor(for: isUser))
        if !isBubbleTransparent(for: isUser) {
            shape.fill(.ultraThinMaterial)
        }
    }

    private func isBubbleTransparent(for isUser: Bool) -> Bool {
        isUser ? userBubbleTransparent : botBubbleTransparent
    }

    private func bubbleFillColor(for isUser: Bool) -> Color {
        if isUser {
            return userBubbleTransparent ? .clear : userConfiguredColor
        }
        return botBubbleTransparent ? .clear : botConfiguredColor
    }

    private func bubbleStrokeColor(for isUser: Bool) -> Color {
        Color.clear
    }

    private func bubbleTextColor(for isUser: Bool) -> Color {
        let isTransparent = isUser ? userBubbleTransparent : botBubbleTransparent
        if isTransparent { return .primary }
        return isUser ? .white : .primary
    }

    private func maxBubbleWidth(for isUser: Bool) -> CGFloat {
        let baseWidth = availableWidth > 0 ? availableWidth : 390
        return baseWidth * (isUser ? clampedUserMessageBubbleWidthRatio : clampedBotMessageBubbleWidthRatio)
    }

    private func sideSpacerMinLength(for isUser: Bool) -> CGFloat {
        widthRatio(for: isUser) >= 1.0 ? 0 : 40
    }

    private func widthRatio(for isUser: Bool) -> CGFloat {
        isUser ? clampedUserMessageBubbleWidthRatio : clampedBotMessageBubbleWidthRatio
    }

    private var clampedUserMessageBubbleWidthRatio: CGFloat {
        CGFloat(min(max(userMessageBubbleWidthRatio, 0.45), 1.0))
    }

    private var clampedBotMessageBubbleWidthRatio: CGFloat {
        CGFloat(min(max(botMessageBubbleWidthRatio, 0.45), 1.0))
    }
}

// MARK: - iOS < 16
struct LegacyEditMessageSheet: View {
    var text: String
    var isUser: Bool
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $draftText)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()
                Spacer()
            }
            .navigationBarTitle(isUser ? "Edit (you)" : "Edit (bot)", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    let textToSave = draftText
                    dismiss()
                    Task { @MainActor in
                        onSave(textToSave)
                    }
                }
            )
        }
        .onAppear {
            draftText = text
        }
        .onChange(of: text) { _, newValue in
            draftText = newValue
        }
    }
}

private func renderedMarkdown(from text: String) -> AttributedString {
    let markdownText = markdownReadyText(from: text)
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )
    if let attributed = try? AttributedString(markdown: markdownText, options: options) {
        return applyingNoHyphenation(to: attributed)
    }
    return applyingNoHyphenation(to: AttributedString(markdownText))
}

private func markdownReadyText(from text: String) -> String {
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

private struct MessageRowPreviewHost: View {
    @StateObject private var message: ChatMessageModel
    private let useGradientBackground: Bool

    init(message: ChatMessageModel, useGradientBackground: Bool = false) {
        _message = StateObject(wrappedValue: message)
        self.useGradientBackground = useGradientBackground
    }

    var body: some View {
        MessageRow(
            msg: message,
            regenerate: { _ in },
            switchVariant: { _, _ in },
            onDelete: { _ in }
        )
        .padding()
        .background(
            Group {
                if useGradientBackground {
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.12, blue: 0.20),
                            Color(red: 0.16, green: 0.23, blue: 0.34),
                            Color(red: 0.24, green: 0.18, blue: 0.27)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(.systemBackground)
                }
            }
        )
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

#Preview("Bot Thinking + Gradient") {
    MessageRowPreviewHost(
        message: ChatMessageModel(
            content: "<think>Reviewing your prompt and outlining the answer structure before responding.</think>Here is the bot response after thinking mode finishes.",
            isUser: false
        ),
        useGradientBackground: true
    )
}
