import SwiftUI

struct EditMessageSheet: View {
    let isUser: Bool
    let botName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool
    @State private var draftText: String

    init(text: String, isUser: Bool, botName: String, onSave: @escaping (String) -> Void) {
        self.isUser = isUser
        self.botName = botName
        self.onSave = onSave
        _draftText = State(initialValue: text)
    }

    var body: some View {
        NavigationStack {
            // The editor owns scrolling and fills the keyboard-safe viewport.
            // Do not size it to its text or put it inside another scroll view.
            TextEditor(text: $draftText)
                .font(.body)
                .focused($isEditorFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .contentMargins(.vertical, 12, for: .scrollContent)
                .background(Color(.systemBackground))
                .accessibilityLabel("Message")
                .accessibilityIdentifier("message-editor.text")
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { dismiss() }
                            .accessibilityIdentifier("message-editor.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .bold()
                            .keyboardShortcut("s", modifiers: .command)
                            .accessibilityIdentifier("message-editor.save")
                    }
                }
                .onAppear { isEditorFocused = true }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        if isUser { return "Edit your message" }
        let possessiveName = botName.lowercased().hasSuffix("s") ? "\(botName)’" : "\(botName)’s"
        return "Edit \(possessiveName) message"
    }

    private func save() {
        onSave(draftText)
        dismiss()
    }
}

#Preview("Edit Message") {
    EditMessageSheet(
        text: "Let's keep the conversation simple.\n\nYou can edit any part of this message, then tap Save when you're ready.",
        isUser: true,
        botName: "Luna",
        onSave: { _ in }
    )
}

#Preview("Long Message · Dark") {
    EditMessageSheet(
        text: String(repeating: "A long message stays scrollable while you edit.\n\n", count: 100),
        isUser: false,
        botName: "James",
        onSave: { _ in }
    )
    .preferredColorScheme(.dark)
}
