//
//  ChatBotSheetView.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


import SwiftUI

struct ChatBotSheetView: View {
    let bot: Bot
    var onNewChat: () -> Void
    var onViewHistory: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isDescriptionExpandedManually = false
    @State private var selectedDetent: PresentationDetent = .medium
    private let collapsedDescriptionCharacterLimit = 140

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Avatar
                    if let data = bot.avatarData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    } else {
                        Image(systemName: bot.avatarSystemName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(bot.iconColor)
                    }

                    // Name
                    Text(bot.name)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Greeting
                    VStack(spacing: 8) {
                        Text("Greeting")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        Text(renderedMarkdown(from: bot.greeting))
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    // Description
                    VStack(spacing: 8) {
                        Text("Character Description")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        Group {
                            Text(renderedMarkdown(from: bot.subtitle))
                                .font(.body)
                                .lineLimit(isDescriptionExpanded ? nil : 3)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if canToggleDescription && !isLargeDetent {
                                Button(action: {
                                    withAnimation {
                                        isDescriptionExpandedManually.toggle()
                                    }
                                }) {
                                    Text(isDescriptionExpandedManually ? "Show Less" : "Show More")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Fixed bottom buttons
            HStack(spacing: 12) {
                Button(action: onViewHistory) {
                    HStack {
                        Image(systemName: "clock")
                        Text("History")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                Button(action: onNewChat) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Chat")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: bot.id) { _, _ in
            isDescriptionExpandedManually = false
        }
    }

    private var isLargeDetent: Bool {
        selectedDetent == .large
    }

    private var isDescriptionExpanded: Bool {
        isLargeDetent || isDescriptionExpandedManually
    }

    private var canToggleDescription: Bool {
        let normalized = normalizedMarkdownText(from: bot.subtitle).trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.count > collapsedDescriptionCharacterLimit || normalized.contains("\n")
    }

    private func renderedMarkdown(from text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let attributed = try? AttributedString(
            markdown: normalizedMarkdownText(from: text),
            options: options
        ) {
            return attributed
        }
        return AttributedString(text)
    }

    private func normalizedMarkdownText(from text: String) -> String {
        text
            .replacingOccurrences(of: "/n/n", with: "\n\n")
            .replacingOccurrences(of: "/n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

#Preview {
    ChatBotSheetView(
        bot: Bot(
            name: "Luna",
            avatarSystemName: "moon.fill",
            iconColor: .purple,
            subtitle: "Luna is your dreamy assistant, always ready to talk about the stars and the universe in poetic ways.",
            date: "Today",
            isPinned: false,
            greeting: "Hi! I'm Luna. Let's explore the stars together. ✨",
            avatarData: nil
        ),
        onNewChat: {},
        onViewHistory: {}
    )
}
