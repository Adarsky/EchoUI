import SwiftUI

struct EditBotView: View {
    let bot: BotModel

    var body: some View {
        CharacterEditorView(bot: bot)
    }
}

#Preview("Edit Character") {
    NavigationStack {
        EditBotView(
            bot: BotModel(
                name: "Luna",
                subtitle: "A thoughtful creative partner who turns ideas into clear next steps.",
                date: "Sep 7, 2026",
                avatarSystemName: "sparkles",
                iconColorName: "purple",
                isPinned: false,
                greeting: "Hi! What would you like to create today?"
            )
        )
    }
    .modelContainer(for: BotModel.self, inMemory: true)
}
