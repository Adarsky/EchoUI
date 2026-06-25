//
//  InputBarSettings.swift
//  FrontendAI
//
//  Created by macbook on 10.05.2026.
//

import SwiftUI

struct InputBarSettings: View {
    @AppStorage(ChatInputBarStorageKeys.sendButtonStyle) private var sendButtonStyleRawValue = ChatInputBarSendButtonStyle.defaultValue.rawValue
    @State private var previewText = "Ask anything..."

    private var selectedSendButtonStyle: Binding<ChatInputBarSendButtonStyle> {
        Binding(
            get: {
                ChatInputBarSendButtonStyle.value(from: sendButtonStyleRawValue)
            },
            set: { newValue in
                sendButtonStyleRawValue = newValue.rawValue
            }
        )
    }

    var body: some View {
        List {
            Section("Preview") {
                ChatInputBar(
                    inputText: $previewText,
                    isGenerating: false,
                    isThinking: false,
                    sendButtonStyle: selectedSendButtonStyle.wrappedValue,
                    placeholder: "Message Assistant",
                    onSend: { },
                    onStop: { }
                )
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section("Chat Input Bar Settings") {
                Picker("Send Button", selection: selectedSendButtonStyle) {
                    ForEach(ChatInputBarSendButtonStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Input Bar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    InputBarSettings()
}
