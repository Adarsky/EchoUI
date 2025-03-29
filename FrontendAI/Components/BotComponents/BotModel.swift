//
//  BotModel.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//


import Foundation
import SwiftData
import SwiftUI

@Model
class BotModel {
    var id: UUID
    var name: String
    var subtitle: String
    var date: String
    var avatarSystemName: String
    var iconColorName: String
    var isPinned: Bool
    var avatarData: Data?
    var greeting: String
    
    @Transient
    var avatarImage: Image {
        if let data = avatarData, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        } else {
            return Image(systemName: avatarSystemName)
        }
    }


    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        date: String,
        avatarSystemName: String,
        iconColorName: String,
        isPinned: Bool,
        avatarData: Data? = nil,
        greeting: String
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.date = date
        self.avatarSystemName = avatarSystemName
        self.iconColorName = iconColorName
        self.isPinned = isPinned
        self.avatarData = avatarData
        self.greeting = greeting
    }

    // Создание BotModel из Bot
    convenience init(from bot: Bot) {
        self.init(
            id: bot.id,
            name: bot.name,
            subtitle: bot.subtitle,
            date: bot.date,
            avatarSystemName: bot.avatarSystemName,
            iconColorName: bot.iconColor.description,
            isPinned: bot.isPinned,
            avatarData: bot.avatarData,
            greeting: bot.greeting
        )
    }

    // Преобразование обратно в Bot
    func asBot() -> Bot {
        Bot(
            id: self.id,
            name: self.name,
            avatarSystemName: self.avatarSystemName,
            iconColor: Color(self.iconColorName),
            subtitle: self.subtitle,
            date: self.date,
            isPinned: self.isPinned,
            greeting: self.greeting,
            avatarData: self.avatarData
        )
    }
}
