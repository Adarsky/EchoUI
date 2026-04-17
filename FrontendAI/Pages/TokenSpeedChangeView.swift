//
//  TokenSpeedChangeView.swift
//  FrontendAI
//
//  Created by macbook on 17.04.2026.
//

import SwiftUI

struct TokenSpeedChangeView: View {
    @AppStorage(ChatStreamingStorageKeys.chunkFlushIntervalMs) private var streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
    @State private var showChunkTimeInfo: Bool = false
    @State private var previewAssistantText = ""
    @State private var isPreviewStreaming = false
    @State private var previewTask: Task<Void, Never>?

    private let previewAssistantFullMessage = "Retry logic improves reliability because temporary issues, like brief packet loss or short server hiccups, often disappear on their own. By retrying with a small delay between attempts, the app can recover without user action and still keep responses fast enough to feel natural."

    var body: some View {
        List {
            Section("Live preview") {
                TokenSpeedChatPreview(
                    assistantMessage: previewAssistantText,
                    fullAssistantMessage: previewAssistantFullMessage,
                    isAssistantStreaming: isPreviewStreaming,
                    onReplay: startPreviewStreaming
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .listRowBackground(Color.clear)
            }
            Section("Live preview") {
                HStack {
                    Image(systemName: "hare")
                    Text("Chunk time: \(Int(streamChunkFlushIntervalMs.rounded())) ms")
                    Spacer()
                    Button {
                        streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                    Button {
                        showChunkTimeInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Chunk time info")
                }
                HStack {
                    Slider(
                        value: $streamChunkFlushIntervalMs,
                        in: ChatStreamingDefaults.minChunkFlushIntervalMs...ChatStreamingDefaults.maxChunkFlushIntervalMs,
                        step: 10
                    )
                }
            }
        }
        .onAppear {
            streamChunkFlushIntervalMs = ChatStreamingDefaults.clampedChunkFlushIntervalMs(streamChunkFlushIntervalMs)
            startPreviewStreaming()
        }
        .onChange(of: streamChunkFlushIntervalMs) { _, newValue in
            let clampedValue = ChatStreamingDefaults.clampedChunkFlushIntervalMs(newValue)
            if clampedValue != newValue {
                streamChunkFlushIntervalMs = clampedValue
                return
            }
            startPreviewStreaming()
        }
        .onDisappear {
            previewTask?.cancel()
        }
        .navigationTitle("Token Speed")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Chunk Time", isPresented: $showChunkTimeInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This controls how often streamed LLM text is flushed to the chat UI. Lower values update text more frequently with smaller chunks. Higher values batch more text per update, which can feel less live but may reduce UI update overhead.")
        }
    }

    private func startPreviewStreaming() {
        previewTask?.cancel()
        let clampedIntervalMs = ChatStreamingDefaults.clampedChunkFlushIntervalMs(streamChunkFlushIntervalMs)

        previewTask = Task {
            await MainActor.run {
                previewAssistantText = ""
                isPreviewStreaming = true
            }

            var streamed = ""
            var pending = ""
            var index = previewAssistantFullMessage.startIndex
            var lastFlush = CFAbsoluteTimeGetCurrent()
            let flushInterval = max(0.01, clampedIntervalMs / 1000)
            let source = previewAssistantFullMessage

            while index < source.endIndex, !Task.isCancelled {
                let tokenLength = Int.random(in: 1...3)
                let nextIndex = source.index(index, offsetBy: tokenLength, limitedBy: source.endIndex) ?? source.endIndex
                pending.append(contentsOf: source[index..<nextIndex])
                index = nextIndex

                let now = CFAbsoluteTimeGetCurrent()
                if (now - lastFlush) >= flushInterval {
                    streamed.append(pending)
                    pending.removeAll(keepingCapacity: true)
                    await MainActor.run {
                        previewAssistantText = streamed
                    }
                    lastFlush = now
                }

                try? await Task.sleep(nanoseconds: 40_000_000)
            }

            guard !Task.isCancelled else { return }

            if !pending.isEmpty {
                streamed.append(pending)
                await MainActor.run {
                    previewAssistantText = streamed
                }
            }

            await MainActor.run {
                isPreviewStreaming = false
            }
        }
    }
}

private struct TokenSpeedChatPreview: View {
    let assistantMessage: String
    let fullAssistantMessage: String
    let isAssistantStreaming: Bool
    let onReplay: () -> Void

    @AppStorage(ChatAppearanceStorageKeys.userBubbleRed) private var userBubbleRed = ChatAppearanceDefaults.userBubbleRed
    @AppStorage(ChatAppearanceStorageKeys.userBubbleGreen) private var userBubbleGreen = ChatAppearanceDefaults.userBubbleGreen
    @AppStorage(ChatAppearanceStorageKeys.userBubbleBlue) private var userBubbleBlue = ChatAppearanceDefaults.userBubbleBlue
    @AppStorage(ChatAppearanceStorageKeys.userBubbleOpacity) private var userBubbleOpacity = ChatAppearanceDefaults.userBubbleOpacity
    @AppStorage(ChatAppearanceStorageKeys.userBubbleTransparent) private var userBubbleTransparent = ChatAppearanceDefaults.userBubbleTransparent
    @AppStorage(ChatAppearanceStorageKeys.userMessageBubbleWidthRatio) private var userMessageBubbleWidthRatio = ChatAppearanceDefaults.userMessageBubbleWidthRatio

    @AppStorage(ChatAppearanceStorageKeys.botMessageBubbleWidthRatio) private var botMessageBubbleWidthRatio = ChatAppearanceDefaults.botMessageBubbleWidthRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack(alignment: .topLeading) {
                    bubbleText(fullAssistantMessage, isUser: false)
                        .hidden()
                    bubbleContent(isUser: false)
                }
                Spacer(minLength: 36)
            }
        }
    }

    @ViewBuilder
    private func bubbleContent(isUser: Bool) -> some View {
        if assistantMessage.isEmpty && isAssistantStreaming {
            TypingIndicator()
                .padding(12)
                .background(bubbleBackground(isUser: isUser))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: maxBubbleWidth(for: isUser), alignment: .leading)
        } else {
            bubbleText(assistantMessage, isUser: isUser)
        }
    }

    private func bubbleText(_ text: String, isUser: Bool) -> some View {
        Text(AttributedString(text))
            .padding(12)
            .background(bubbleBackground(isUser: isUser))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.clear, lineWidth: 1)
            )
            .foregroundColor(bubbleTextColor(isUser: isUser))
            .frame(maxWidth: maxBubbleWidth(for: isUser), alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private func bubbleBackground(isUser: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape.fill(bubbleFillColor(isUser: isUser))
        if !isBubbleTransparent(isUser: isUser) {
            shape.fill(.ultraThinMaterial)
        }
    }

    private func isBubbleTransparent(isUser: Bool) -> Bool {
        if !isUser { return true }
        return userBubbleTransparent
    }

    private func bubbleFillColor(isUser: Bool) -> Color {
        if !isUser { return .clear }
        return userBubbleTransparent ? .clear : userConfiguredColor
    }

    private func bubbleTextColor(isUser: Bool) -> Color {
        let transparent = isBubbleTransparent(isUser: isUser)
        if transparent { return .primary }
        return isUser ? .white : .primary
    }

    private func maxBubbleWidth(for isUser: Bool) -> CGFloat {
        let ratio = isUser
            ? CGFloat(min(max(userMessageBubbleWidthRatio, 0.45), 1.0))
            : CGFloat(min(max(botMessageBubbleWidthRatio, 0.45), 1.0))
        return UIScreen.main.bounds.width * ratio
    }

    private var userConfiguredColor: Color {
        ChatAppearanceColor.makeColor(
            red: userBubbleRed,
            green: userBubbleGreen,
            blue: userBubbleBlue,
            opacity: userBubbleOpacity
        )
    }
}

#Preview {
    TokenSpeedChangeView()
}
