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

    @FocusState private var isTextFieldFocused: Bool
    @State private var textHeight: CGFloat = 36
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
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text(placeholder)
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                    }

                    TextEditor(text: $inputText)
                        .focused($isTextFieldFocused)
                        .frame(height: textHeight)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .onChange(of: inputText) { _ in
                            adjustHeight()
                        }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
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
        .onChange(of: isGenerating) { _ in
            reconcileButtonState()
        }
        .onChange(of: isThinking) { _ in
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

    private func adjustHeight() {
        let font = UIFont.systemFont(ofSize: 17)
        let textView = UITextView()
        textView.font = font
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) {
                textHeight = 36
            }
            return
        }
        
        textView.text = inputText
        let maxWidth = UIScreen.main.bounds.width - 32 - 16 - 36 - 8 - 16
        let size = textView.sizeThatFits(CGSize(width: maxWidth, height: .infinity))
        let calculatedHeight = size.height + 12

        withAnimation(.easeInOut(duration: 0.2)) {
            textHeight = min(max(calculatedHeight, 36), 148)
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
        .background(Color(.systemBackground))
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
