import SwiftUI

struct CreateCharacterView: View {
    var onCreate: (() -> Void)?

    var body: some View {
        CharacterEditorView(onCreate: onCreate)
    }
}

typealias CreateBotView = CreateCharacterView

#Preview {
    NavigationStack {
        CreateCharacterView()
    }
    .modelContainer(for: BotModel.self, inMemory: true)
}
