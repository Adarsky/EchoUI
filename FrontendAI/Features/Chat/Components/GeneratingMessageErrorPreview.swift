#if DEBUG
import SwiftUI

struct GeneratingMessageErrorPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var assistantMessage = ChatMessageModel(content: "", isUser: false)
    @State private var availableWidth: CGFloat = 390
    @State private var isGenerating = true
    @State private var replayID = 0

    private let userMessage = ChatMessageModel(
        content: "Create a concise launch checklist for my new app.",
        isUser: true
    )

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: isGenerating ? "sparkles" : "wifi.exclamationmark")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(
                        .breathe.pulse.byLayer,
                        options: .repeat(.continuous),
                        isActive: isGenerating && !reduceMotion
                    )
                    .foregroundStyle(isGenerating ? Color.secondary : Color.red)
                    .accessibilityHidden(true)

                Text(isGenerating ? "Generating reply…" : "Generation interrupted")
                    .font(.subheadline)
                    .bold()

                Spacer()

                Button(
                    "Replay Scenario",
                    systemImage: "arrow.counterclockwise",
                    action: replayScenario
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .animation(.easeOut(duration: 0.2), value: isGenerating)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    MessageRow(
                        msg: userMessage,
                        availableWidth: rowWidth,
                        regenerate: { _ in },
                        switchVariant: { _, _ in },
                        onDelete: { _ in }
                    )

                    MessageRow(
                        msg: assistantMessage,
                        availableWidth: rowWidth,
                        regenerate: { _ in replayScenario() },
                        switchVariant: { _, _ in },
                        onDelete: { _ in }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .environment(\.isGenerating, isGenerating)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { newWidth in
            availableWidth = newWidth
        }
        .task(id: replayID) {
            await playScenario()
        }
    }

    private var rowWidth: CGFloat {
        max(1, availableWidth - 32)
    }

    private func replayScenario() {
        replayID &+= 1
    }

    @MainActor
    private func playScenario() async {
        assistantMessage.replaceCurrentVariant(with: "")
        assistantMessage.setStreaming(true)
        isGenerating = true

        guard await pause(for: .milliseconds(650)) else { return }
        assistantMessage.appendChunk(
            "I’ll turn that into a focused checklist.",
            to: assistantMessage.currentIndex
        )

        guard await pause(for: .milliseconds(700)) else { return }
        assistantMessage.appendChunk(
            "\n\n1. Confirm the release scope and owners.",
            to: assistantMessage.currentIndex
        )

        guard await pause(for: .milliseconds(700)) else { return }
        assistantMessage.appendChunk(
            "\n2. Prepare App Store assets and release notes.",
            to: assistantMessage.currentIndex
        )

        guard await pause(for: .milliseconds(850)) else { return }
        assistantMessage.setFailure(
            ChatReplyFailure(
                kind: .connectionInterrupted,
                message: "The connection dropped while the reply was being generated."
            )
        )
        isGenerating = false
    }

    private func pause(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
#endif
