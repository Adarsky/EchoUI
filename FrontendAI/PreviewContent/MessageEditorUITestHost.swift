#if DEBUG
import SwiftUI

/// Exercises the real chat row and its context menu without a server or saved chats.
struct MessageEditorUITestHost: View {
    @StateObject private var message: ChatMessageModel
    @State private var inputText = ""
    @State private var savedEdits = 0

    init() {
        let isUser = ProcessInfo.processInfo.arguments.contains("--user-message")
        let text = isUser ? "Original message" : (1...120).map {
            "Paragraph \($0). A long message should remain easy to read and edit. Select any line, move the cursor, and keep writing.\n\n"
        }.joined() + "END_MARKER"
        _message = StateObject(wrappedValue: ChatMessageModel(content: text, isUser: isUser))
    }

    var body: some View {
        NavigationStack {
            ChatScreenView(
                model: ChatScreenModel(
                    messages: [message],
                    botName: "Luna",
                    appearance: .defaultValue,
                    composer: .init(
                        isGenerating: false,
                        isThinking: false,
                        sendButtonStyle: .defaultValue,
                        placeholder: "Message"
                    )
                ),
                bindings: ChatScreenBindings(inputText: $inputText),
                actions: ChatScreenActions(
                    messages: .init(
                        regenerate: { _ in },
                        switchVariant: { _, _ in },
                        edit: { _ in savedEdits += 1 },
                        delete: { _ in },
                        branch: { _ in }
                    ),
                    composer: .init(send: {}, stop: {})
                )
            )
            .navigationTitle("Saved edits: \(savedEdits)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
