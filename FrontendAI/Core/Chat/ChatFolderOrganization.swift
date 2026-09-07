import Foundation

enum ChatFolderOrganization {
    static func isPinned(_ bot: BotModel, in folder: ChatFolder?) -> Bool {
        guard let folder else { return bot.isPinned }
        return folder.pinnedBotIDStrings.contains(ChatFolder.storageID(for: bot.id))
    }

    static func pinnedBots(from bots: [BotModel], in folder: ChatFolder?) -> [BotModel] {
        if let folder {
            let botsByID = Dictionary(uniqueKeysWithValues: bots.map { (ChatFolder.storageID(for: $0.id), $0) })
            return folder.pinnedBotIDStrings.compactMap { botsByID[$0] }
        }
        return bots.filter(\.isPinned).sorted {
            if $0.pinnedSortIndex == $1.pinnedSortIndex {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.pinnedSortIndex < $1.pinnedSortIndex
        }
    }

    static func togglePin(_ bot: BotModel, in folder: ChatFolder?, bots: [BotModel]) {
        if let folder {
            let id = ChatFolder.storageID(for: bot.id)
            guard folder.contains(botID: bot.id) else { return }
            if folder.pinnedBotIDStrings.contains(id) {
                folder.pinnedBotIDStrings.removeAll { $0 == id }
            } else {
                folder.pinnedBotIDStrings.append(id)
            }
            folder.updatedAt = .now
        } else if bot.isPinned {
            bot.isPinned = false
            bot.pinnedSortIndex = 0
        } else {
            pinInAllChats(bot, bots: bots)
        }
    }

    static func applyPinnedOrder(_ orderedBots: [BotModel], in folder: ChatFolder?, bots: [BotModel]) {
        let reorderedIDs = orderedBots.map { ChatFolder.storageID(for: $0.id) }
        let reorderedSet = Set(reorderedIDs)
        var replacements = reorderedIDs.makeIterator()
        // Keep pins currently hidden from this list in their existing positions.
        let existingIDs = folder?.pinnedBotIDStrings ?? pinnedBots(from: bots, in: nil).map { ChatFolder.storageID(for: $0.id) }
        let mergedIDs = existingIDs.map { reorderedSet.contains($0) ? (replacements.next() ?? $0) : $0 }
        if let folder {
            folder.pinnedBotIDStrings = mergedIDs
            folder.updatedAt = .now
        } else {
            let botsByID = Dictionary(uniqueKeysWithValues: bots.map { (ChatFolder.storageID(for: $0.id), $0) })
            for (index, id) in mergedIDs.enumerated() {
                botsByID[id]?.pinnedSortIndex = index
            }
        }
    }

    static func replaceMembers(of folder: ChatFolder, with memberIDs: [String], bots: [BotModel], folders: [ChatFolder]) {
        let visibleBefore = allChatIDs(bots: bots, folders: folders)
        let newMembers = Set(memberIDs)
        let returningPins = pinnedBots(from: bots, in: folder).filter {
            folder.contains(botID: $0.id)
                && !newMembers.contains(ChatFolder.storageID(for: $0.id))
                && !visibleBefore.contains($0.id)
        }

        folder.botIDStrings = memberIDs
        folder.pinnedBotIDStrings.removeAll { !newMembers.contains($0) }
        folder.updatedAt = .now

        let visibleAfter = allChatIDs(bots: bots, folders: folders)
        for bot in returningPins where visibleAfter.contains(bot.id) && !bot.isPinned {
            pinInAllChats(bot, bots: bots)
        }
    }

    private static func pinInAllChats(_ bot: BotModel, bots: [BotModel]) {
        let nextIndex = (bots.filter(\.isPinned).map(\.pinnedSortIndex).max() ?? -1) + 1
        bot.isPinned = true
        bot.pinnedSortIndex = nextIndex
    }

    private static func allChatIDs(bots: [BotModel], folders: [ChatFolder]) -> Set<UUID> {
        Set(PrivateChatVisibility.visibleBots(
            from: bots, folders: folders, foldersEnabled: true,
            selectedFolderID: ChatFolder.allFolderID, unlockedPrivateFolderID: nil
        ).map(\.id))
    }
}
