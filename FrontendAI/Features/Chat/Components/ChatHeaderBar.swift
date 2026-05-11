import SwiftUI

struct ChatHeaderBar: View {
    let bot: Bot
    let botID: UUID
    let chatAppearanceID: String?

    @Binding var showChatBotSheet: Bool
    @Binding var isViewingHistory: Bool
    @Namespace var chatBotSheetNamespace
    let onNewChat: () -> Void

    var body: some View {
        GlassEffectContainer {
            HStack {
                Button { showChatBotSheet = true } label: {
                    HStack(spacing: 6) {
                        if let data = bot.avatarData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .offset(x: -5)
                        } else {
                            Image(systemName: bot.avatarSystemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(bot.iconColor)
                                .offset(x: -5)
                        }
                        Text(bot.name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: 280)
                .buttonStyle(.glass)
                .glassEffectUnion(id: 1, namespace: chatBotSheetNamespace)
                .sheet(isPresented: $showChatBotSheet) {
                    ChatBotSheetView(
                        bot: bot,
                        botID: botID,
                        chatAppearanceID: chatAppearanceID,
                        onNewChat: {
                            onNewChat()
                            showChatBotSheet = false
                        },
                        onViewHistory: {
                            showChatBotSheet = false
                            isViewingHistory = true
                        }
                    )
                }
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
