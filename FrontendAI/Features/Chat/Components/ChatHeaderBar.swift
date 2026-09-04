import SwiftUI

struct ChatHeaderBar: View {
    let bot: Bot
    @Binding var showCharacterProfile: Bool

    var body: some View {
        HStack () {
                Button { showCharacterProfile = true } label: {
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
        showCharacterProfile: .constant(false)
    )
}
