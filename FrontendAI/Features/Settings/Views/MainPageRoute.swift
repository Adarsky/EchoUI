import Foundation

enum MainPageRoute: Hashable {
    case chat(botID: UUID)
    case editCharacter(botID: UUID)
    case createCharacter
    case createPersona
}
