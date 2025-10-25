//
//  Message.swift
//  FrontendAI
//
//  Created by macbook on 25.03.2025.
//


import SwiftUI
import SwiftData

@Model
class Message {
    var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var botID: UUID
    
    var variants: [String]?
    var currentIndex: Int?

    init(content: String, isUser: Bool, botID: UUID, timestamp: Date = Date(),variants: [String]? = nil, currentIndex: Int? = nil) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.botID = botID
        self.variants = variants
        self.currentIndex = currentIndex
    }
}
