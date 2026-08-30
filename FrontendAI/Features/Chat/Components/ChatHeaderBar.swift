import SwiftUI

struct ChatHeaderBar: View {
    let bot: Bot
    let botID: UUID
    let chatAppearanceID: String?
    var currentChatTokenCount = 0
    var tokenWindow: Int?
    var personas: [PersonaModel] = []
    var currentPersona: PersonaModel?
    var globalPersona: PersonaModel?
    var hasPersonaOverride = false

    @Binding var showChatBotSheet: Bool
    @Binding var isViewingHistory: Bool
    @Namespace var chatBotSheetNamespace
    let onNewChat: () -> Void
    var onSelectPersona: (PersonaModel?) -> Void = { _ in }
    var onUseGlobalPersona: () -> Void = { }

    var body: some View {
        HStack () {
                Button { showChatBotSheet = true } label: {
                        if let data = bot.avatarData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 38, height: 38)
                                .clipShape(Circle())
                                .offset(x: -5)
                        } else {
                            Image(systemName: bot.avatarSystemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 38, height: 38)
                                .foregroundColor(bot.iconColor)
                                .offset(x: -5)
                        }
                        Text(bot.name)
                        .font(.system(size: 18).bold())
                            .lineLimit(1)
                            .foregroundColor(.white)
                }
                .sheet(isPresented: $showChatBotSheet) {
                    ChatBotSheetView(
                        bot: bot,
                        botID: botID,
                        chatAppearanceID: chatAppearanceID,
                        currentChatTokenCount: currentChatTokenCount,
                        tokenWindow: tokenWindow,
                        personas: personas,
                        currentPersona: currentPersona,
                        globalPersona: globalPersona,
                        hasPersonaOverride: hasPersonaOverride,
                        onNewChat: {
                            onNewChat()
                            showChatBotSheet = false
                        },
                        onViewHistory: {
                            showChatBotSheet = false
                            isViewingHistory = true
                        },
                        onSelectPersona: onSelectPersona,
                        onUseGlobalPersona: onUseGlobalPersona
                    )
            }
        }
    }
}

#Preview {
    ChatHeaderBar(
        bot: Bot(
            name: "Assistant",
            avatarSystemName: "circle.circle.fill",
            iconColor: .blue,
            subtitle: "Ready to help",
            date: "Today",
            isPinned: false,
            greeting: "Hi!",
            avatarData: nil
        ),
        botID: UUID(),
        chatAppearanceID: nil,
        showChatBotSheet: .constant(false),
        isViewingHistory: .constant(false),
        onNewChat: { }
    )
}
