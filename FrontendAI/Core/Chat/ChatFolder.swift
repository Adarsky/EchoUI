import Foundation
import SwiftData

@Model
final class ChatFolder {
    static let allFolderID = "all"
    static let privateFolderName = "private"
    static let maxNameLength = 28

    var id: UUID
    var name: String
    var symbolName: String
    var colorName: String = ChatFolderColor.defaultValue.rawValue
    var botIDStrings: [String]
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "folder",
        colorName: String = ChatFolderColor.defaultValue.rawValue,
        botIDStrings: [String] = [],
        sortIndex: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = Self.clampedName(name)
        self.symbolName = symbolName
        self.colorName = ChatFolderColor(rawValue: colorName)?.rawValue ?? ChatFolderColor.defaultValue.rawValue
        self.botIDStrings = botIDStrings
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        name.isEmpty ? "Folder" : name
    }

    var displayColor: ChatFolderColor {
        ChatFolderColor(rawValue: colorName) ?? .defaultValue
    }

    var isPrivate: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(Self.privateFolderName) == .orderedSame
    }

    func contains(botID: UUID) -> Bool {
        botIDStrings.contains(Self.storageID(for: botID))
    }

    func setContains(_ isIncluded: Bool, botID: UUID) {
        let storageID = Self.storageID(for: botID)

        if isIncluded {
            if !botIDStrings.contains(storageID) {
                botIDStrings.append(storageID)
            }
        } else {
            botIDStrings.removeAll { $0 == storageID }
        }

        updatedAt = .now
    }

    func toggle(botID: UUID) {
        setContains(!contains(botID: botID), botID: botID)
    }

    static func storageID(for botID: UUID) -> String {
        botID.uuidString.lowercased()
    }

    static func clampedName(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
    }
}

enum PrivateChatVisibility {
    static func visibleBots(
        from bots: [BotModel],
        folders: [ChatFolder],
        foldersEnabled: Bool,
        selectedFolderID: String,
        unlockedPrivateFolderID: String?
    ) -> [BotModel] {
        let privateBotIDs = Set(
            folders
                .filter(\.isPrivate)
                .flatMap(\.botIDStrings)
                .compactMap(UUID.init(uuidString:))
        )
        let privacyFilteredBots = bots.filter { !privateBotIDs.contains($0.id) }

        guard foldersEnabled else { return privacyFilteredBots }
        guard selectedFolderID != ChatFolder.allFolderID else { return privacyFilteredBots }
        guard let selectedFolder = folders.first(where: { $0.id.uuidString == selectedFolderID }) else {
            return privacyFilteredBots
        }

        if selectedFolder.isPrivate {
            guard unlockedPrivateFolderID == selectedFolderID else { return [] }
            return bots.filter { selectedFolder.contains(botID: $0.id) }
        }

        return privacyFilteredBots.filter { selectedFolder.contains(botID: $0.id) }
    }
}
