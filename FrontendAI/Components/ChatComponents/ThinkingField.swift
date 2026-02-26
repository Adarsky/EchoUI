import SwiftUI

struct ThinkingField: View {
    @ObservedObject var msg: ChatMessageModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(msg.thinkingStatusText)
                        .font(.footnote.weight(.semibold))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.glass)

            if isExpanded {
                ThinkingStreamPanel(
                    sourceText: msg.thinkingContent,
                    isStreaming: msg.isThinkingInProgress
                )
                .frame(height: 180)
                .transition(.opacity)
            }
        }
        .onChange(of: msg.currentIndex) { _, _ in
            isExpanded = false
        }
    }
}

private struct ThinkingStreamPanel: View {
    let sourceText: String
    let isStreaming: Bool

    @State private var renderedText = ""
    @State private var lastUpdateTime = Date.distantPast

    private let liveWindowChars = 4_000
    private let streamingUpdateInterval: TimeInterval = 1.0 / 8.0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(renderedText)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transaction { transaction in
            transaction.animation = nil
        }
        .onAppear {
            renderedText = makeDisplayText(from: sourceText, isStreaming: isStreaming)
            lastUpdateTime = Date()
        }
        .onChange(of: sourceText) { _, newValue in
            if isStreaming {
                let now = Date()
                guard now.timeIntervalSince(lastUpdateTime) >= streamingUpdateInterval else { return }
                lastUpdateTime = now
            }
            renderedText = makeDisplayText(from: newValue, isStreaming: isStreaming)
        }
        .onChange(of: isStreaming) { _, newValue in
            if !newValue {
                renderedText = makeDisplayText(from: sourceText, isStreaming: false)
            }
        }
    }

    private func makeDisplayText(from text: String, isStreaming: Bool) -> String {
        guard isStreaming, text.count > liveWindowChars else { return text }
        return "…\(text.suffix(liveWindowChars))"
    }
}
