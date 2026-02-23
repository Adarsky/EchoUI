//
//  ChatInputBar.swift
//  FrontendAI
//
//  Created by macbook on 03.07.2025.
//


import SwiftUI

struct ChatInputBar: View {
    @Binding var inputText: String
    @Binding var isGenerating: Bool
    @Binding var isThinking: Bool
    let placeholder: String

    let onSend: () -> Void
    let onStop: () -> Void

    @State private var buttonVisualState: ButtonVisualState = .idle
    @State private var postThinkingTask: Task<Void, Never>? = nil

    private enum ButtonVisualState: Equatable {
        case idle
        case thinking
        case thinkingDone
        case generating

        var symbolName: String {
            switch self {
            case .idle:
                return "arrow.up"
            case .thinking:
                return "circle.hexagongrid"
            case .thinkingDone:
                return "checkmark"
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
                TextField(placeholder, text: $inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .frame(maxWidth: .infinity)
                Spacer()

                Button(action: {
                    if buttonVisualState.isStopAction {
                        onStop()
                    } else {
                        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSend()
                    }
                }) {
                    Image(systemName: buttonVisualState.symbolName)
                        .font(.system(size: 31, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                        .symbolEffect(
                            .breathe.pulse.byLayer,
                            options: .repeat(.continuous),
                            isActive: buttonVisualState == .thinking
                        )
                }
                .frame(width: 40, height: 30)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
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
        postThinkingTask?.cancel()
        postThinkingTask = nil

        if !isGenerating {
            setButtonState(.idle, animated: animated)
            return
        }

        if isThinking {
            setButtonState(.thinking, animated: animated)
            return
        }

        if buttonVisualState == .thinking || buttonVisualState == .thinkingDone {
            setButtonState(.thinkingDone, animated: animated)
            postThinkingTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled else { return }
                if isGenerating, !isThinking {
                    setButtonState(.generating, animated: true)
                }
            }
            return
        }

        setButtonState(.generating, animated: animated)
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
