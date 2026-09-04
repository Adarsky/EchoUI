import SwiftData
import SwiftUI

struct MainPageDestinationView: View {
    let route: MainPageRoute

    @Query private var bots: [BotModel]

    var body: some View {
        Group {
            switch route {
            case let .chat(botID):
                if let bot = bot(withID: botID) {
                    ChatView(bot: bot.asBot())
                } else {
                    missingCharacterView
                }
            case let .editCharacter(botID):
                if let bot = bot(withID: botID) {
                    EditBotView(bot: bot)
                } else {
                    missingCharacterView
                }
            case .createCharacter:
                CreateBotView()
            case .createPersona:
                CreatePersonaView()
            }
        }
    }

    private func bot(withID botID: UUID) -> BotModel? {
        bots.first { $0.id == botID }
    }

    private var missingCharacterView: some View {
        ContentUnavailableView(
            "Character Unavailable",
            systemImage: "person.crop.circle.badge.questionmark",
            description: Text("This character is no longer in the local store.")
        )
    }
}
