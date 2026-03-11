//
//  ChatHistory.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


//
//  ChatHistory.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//

import Foundation
import SwiftData

@Model
class ChatHistory {
    @Attribute
    var messages: [ChatMessageEntity]
    
    @Attribute
    var date: Date
    
    @Relationship
    var bot: BotModel
    
    @Attribute
    var botID: UUID

    init(messages: [ChatMessageEntity], date: Date = .now, bot: BotModel) {
        self.messages = messages
        self.date = date
        self.bot = bot
        self.botID = bot.id
    }
}

@Model
class ChatMessageEntity: Identifiable {
    var id: UUID
    var text: String
    var isUser: Bool
    var index: Int
    var timestamp: Date?
    var variants: [String]?
    var currentVariantIndex: Int?

    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        index: Int,
        timestamp: Date? = nil,
        variants: [String]? = nil,
        currentVariantIndex: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.index = index
        self.timestamp = timestamp
        self.variants = variants
        self.currentVariantIndex = currentVariantIndex
    }
}

