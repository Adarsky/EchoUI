import SwiftUI

struct ChatInputBar: View {
    @Binding var inputText: String
    @Binding var isGenerating: Bool
    @Binding var isThinking: Bool
    let placeholder: String

    let onSend: () -> Void
    let onStop: () -> Void

    @State private var buttonVisualState: ButtonVisualState = .idle

    private enum ButtonVisualState: Equatable {
        case idle
        case thinking
        case generating

        var symbolName: String {
            switch self {
            case .idle:
                return "arrow.up"
            case .thinking:
                return "circle.hexagongrid"
            case .generating:
                return "stop.fill"
            }
        }

        var isStopAction: Bool {
            self != .idle
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                inputField
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .onAppear {
            reconcileButtonState(animated: false)
        }
        .onChange(of: isGenerating) { _, _ in
            reconcileButtonState()
        }
        .onChange(of: isThinking) { _, _ in
            reconcileButtonState()
        }
    }

    private func reconcileButtonState(animated: Bool = true) {
        if !isGenerating {
            setButtonState(.idle, animated: animated)
            return
        }

        if isThinking {
            setButtonState(.thinking, animated: animated)
            return
        }

        setButtonState(.generating, animated: animated)
    }

    private var inputField: some View {
        TextField(placeholder, text: $inputText, axis: .vertical)
            .lineLimit(1...10)
            .padding(.vertical)
            .padding(.leading, 14)
            .padding(.trailing, 56)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                sendButton
            }
    }

    private var sendButton: some View {
        Button(action: performPrimaryAction) {
            Image(systemName: buttonVisualState.symbolName)
                .font(.system(size: 27, weight: .semibold))
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                .foregroundColor(Color(.black))
                .frame(width: 50, height: 40)
                .symbolEffect(
                    .breathe.pulse.byLayer,
                    options: .repeat(.continuous),
                    isActive: buttonVisualState == .thinking
                )
        }
        .buttonBorderShape(.capsule)
        .glassEffect(.regular.tint(.white.opacity(1.0)).interactive())
        .frame(width: 40, height: 40)
        .padding(.trailing, 12)
    }

    private func performPrimaryAction() {
        if buttonVisualState.isStopAction {
            onStop()
            return
        }

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend()
    }

    private func setButtonState(_ newState: ButtonVisualState, animated: Bool) {
        guard buttonVisualState != newState else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.28)) {
                buttonVisualState = newState
            }
        } else {
            buttonVisualState = newState
        }
    }
}

private struct ChatInputBarPreviewHost: View {
    @State private var inputText: String
    @State private var isGenerating: Bool
    @State private var isThinking: Bool

    init(inputText: String = "", isGenerating: Bool = false, isThinking: Bool = false) {
        _inputText = State(initialValue: inputText)
        _isGenerating = State(initialValue: isGenerating)
        _isThinking = State(initialValue: isThinking)
    }

    var body: some View {
        ChatInputBar(
            inputText: $inputText,
            isGenerating: $isGenerating,
            isThinking: $isThinking,
            placeholder: "Message Assistant",
            onSend: { },
            onStop: {
                isGenerating = false
                isThinking = false
            }
        )
        .padding(.vertical, 8)
    }
}

#Preview("Idle") {
    ChatInputBarPreviewHost()
}

#Preview("Generating") {
    ChatInputBarPreviewHost(inputText: "Draft prompt...", isGenerating: true)
}

#Preview("Thinking") {
    ChatInputBarPreviewHost(inputText: "Draft prompt...", isGenerating: true, isThinking: true)
}
