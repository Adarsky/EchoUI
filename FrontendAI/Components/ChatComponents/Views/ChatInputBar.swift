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
    let placeholder: String

    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @State private var textHeight: CGFloat = 36

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

                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 31, weight: .semibold))
                    }
                    .frame(width: 40, height: 30)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                } else {
                    Button(action: {
                        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSend()
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 31, weight: .semibold))
                    }
                    .frame(width: 40, height: 30)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
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

    init(inputText: String = "", isGenerating: Bool = false) {
        _inputText = State(initialValue: inputText)
        _isGenerating = State(initialValue: isGenerating)
    }

    var body: some View {
        ChatInputBar(
            inputText: $inputText,
            isGenerating: $isGenerating,
            placeholder: "Message Assistant",
            onSend: { },
            onStop: { isGenerating = false }
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
