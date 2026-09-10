import Foundation
import SwiftData

struct CharacterDraft: Equatable {
    var name = ""
    var description = ""
    var greeting = ""
    var avatarData: Data?

    init(bot: BotModel? = nil) {
        if let bot {
            name = bot.name
            description = bot.subtitle
            greeting = bot.greeting
            avatarData = bot.avatarData
        }
    }

    var normalized: Self {
        var result = self
        result.name = BotModel.clampedName(name.trimmingCharacters(in: .whitespacesAndNewlines))
        result.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        result.greeting = greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    func validationMessage(requiresPhoto: Bool) -> String? {
        let value = normalized
        if value.name.isEmpty {
            return "Add a name to save this character."
        }
        if value.description.isEmpty {
            return "Add a description to save this character."
        }
        if requiresPhoto && avatarData == nil {
            return "Add a photo to create this character."
        }
        return nil
    }

    func hasChanges(from bot: BotModel) -> Bool {
        normalized != Self(bot: bot).normalized
    }

    @MainActor
    func save(in context: ModelContext, editing bot: BotModel?) throws {
        if let bot {
            let previous = Self(bot: bot)
            normalized.apply(to: bot)
            do {
                try context.save()
            } catch {
                // Restore only this editor's fields, preserving other pending work.
                previous.apply(to: bot)
                throw error
            }
        } else {
            let value = normalized
            let newBot = BotModel(
                name: value.name,
                subtitle: value.description,
                date: Date.now.formatted(date: .abbreviated, time: .omitted),
                avatarSystemName: "person.crop.circle.fill",
                iconColorName: "blue",
                isPinned: false,
                avatarData: value.avatarData,
                greeting: value.greeting
            )
            context.insert(newBot)
            do {
                try context.save()
            } catch {
                context.delete(newBot)
                throw error
            }
        }
    }

    private func apply(to bot: BotModel) {
        bot.name = name
        bot.subtitle = description
        bot.greeting = greeting
        bot.avatarData = avatarData
    }
}
