import SwiftUI

struct UsageAvatar: View {
    let bot: BotModel?

    var body: some View {
        Group {
            if let bot, bot.avatarData != nil {
                bot.avatarImage
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: bot?.avatarSystemName ?? "person.crop.circle.badge.questionmark")
                    .font(.title3)
                    .foregroundStyle(UsageStyle.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(UsageStyle.accent.opacity(0.1))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}
