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
    
    init(content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
