//
//  ChatInputBar.swift
//  FrontendAI
//
//  Created by macbook on 03.07.2025.
//


//
//  ChatInputBar.swift
//  FrontendAI
//
//  Created by macbook on 30.03.2025.
//

import SwiftUI

/// Нижняя панель ввода + кнопка send/stop.
/// Логику отправки передаём через замыкания,
/// чтобы само View не знало о сетевом слое.
struct ChatInputBar: View {
    @Binding var inputText: String
    @Binding var isGenerating: Bool
    let placeholder: String

    // Действия
    let onSend: () -> Void
    let onStop: () -> Void

    // Focus
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.gray.opacity(0.10))
                .frame(height: 64)
                .overlay(
                    HStack {
                        TextField(placeholder, text: $inputText, axis: .vertical)
                            .focused($isTextFieldFocused)
                            .foregroundColor(.primary)
                            .padding(12)

                        Spacer()

                        if isGenerating {
                            Button(action: onStop) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .padding(.trailing, 12)
                            }
                        } else {
                            Button(action: {
                                guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                onSend()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
    }
}
