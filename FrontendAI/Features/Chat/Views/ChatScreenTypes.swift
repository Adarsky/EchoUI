import SwiftUI

struct ChatScreenModel {
    let messages: [ChatMessageModel]
    let botName: String
    let appearance: ChatAppearanceSnapshot
    let composer: Composer

    struct Composer {
        let isGenerating: Bool
        let isThinking: Bool
        let sendButtonStyle: ChatInputBarSendButtonStyle
        let placeholder: String
    }
}

struct ChatScreenBindings {
    let inputText: Binding<String>
}

struct ChatScreenActions {
    let messages: Messages
    let composer: Composer

    struct Messages {
        let regenerate: (ChatMessageModel) -> Void
        let switchVariant: (UUID, Int) -> Void
        let edit: (UUID) -> Void
        let delete: (UUID) -> Void
        let branch: (UUID) -> Void
    }

    struct Composer {
        let send: () -> Void
        let stop: () -> Void
    }
}
