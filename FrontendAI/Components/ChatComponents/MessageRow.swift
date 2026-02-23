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

    @State private var isEditing = false
    @State private var editedText = ""
    @State private var showDeleteConfirm = false
    @State private var isThinkingExpanded = false
    
    @Namespace var MessageRowGlassContainer

    var body: some View {
        HStack(alignment: .top) {
            if msg.isUser { Spacer(minLength: 40) }

            LazyVStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {
                if !msg.isUser, msg.hasThinkingContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.26)) {
                            isThinkingExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(msg.thinkingStatusText)
                                .font(.footnote.weight(.semibold))

                            Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if isThinkingExpanded {
                        ThinkingStreamPanel(sourceText: msg.thinkingContent)
                            .frame(height: 180)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
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
                } else {
                    Text(renderedMarkdown(from: msg.content))
                        .id(msg.currentIndex)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(bubbleFillColor(for: msg.isUser))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(bubbleStrokeColor(for: msg.isUser), lineWidth: 1)
                        )
                        .foregroundColor(bubbleTextColor(for: msg.isUser))
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = msg.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            Button {
                                editedText = msg.content
                                isEditing = true
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

            if !msg.isUser { Spacer(minLength: 40) }
        }

        .animation(.easeOut(duration: 0.15), value: msg.currentIndex)
        .sheet(isPresented: $isEditing) {
            LegacyEditMessageSheet(
                text: editedText,
                isUser: msg.isUser,
                onSave: { newText in
                    Task { @MainActor in
                        msg.replaceCurrentVariant(with: newText)
                    }
                }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(msg.isUser ? "User's message" : "Bot's message")
        .onChange(of: msg.currentIndex) { _, _ in
            isThinkingExpanded = false
        }
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

    private func bubbleFillColor(for isUser: Bool) -> Color {
        if isUser {
            return userBubbleTransparent ? .clear : userConfiguredColor
        }
        return botBubbleTransparent ? .clear : botConfiguredColor
    }

    private func bubbleStrokeColor(for isUser: Bool) -> Color {
        let isTransparent = isUser ? userBubbleTransparent : botBubbleTransparent
        if isTransparent {
            return Color.primary.opacity(0.24)
        }
        return Color.clear
    }

    private func bubbleTextColor(for isUser: Bool) -> Color {
        let isTransparent = isUser ? userBubbleTransparent : botBubbleTransparent
        if isTransparent { return .primary }
        return isUser ? .white : .primary
    }
}

private struct ThinkingStreamPanel: View {
    let sourceText: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(sourceText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
    }
}

// MARK: - iOS < 16
struct LegacyEditMessageSheet: View {
    var text: String
    var isUser: Bool
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""
    @State private var didSeedDraft = false

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
            guard !didSeedDraft else { return }
            draftText = text
            didSeedDraft = true
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
        return attributed
    }
    return AttributedString(text)
}

private func markdownReadyText(from text: String) -> String {
    let normalizedText = text
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
