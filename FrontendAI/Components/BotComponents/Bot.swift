//
//  Bot.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//

import Foundation
import SwiftUI

struct Bot: Identifiable, Hashable {
    let id: UUID
    let name: String
    let avatarSystemName: String
    let iconColor: Color
    let subtitle: String
    let date: String
    let isPinned: Bool
    let greeting: String
    let avatarData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        avatarSystemName: String,
        iconColor: Color,
        subtitle: String,
        date: String,
        isPinned: Bool,
        greeting: String,
        avatarData: Data?
    ) {
        self.id = id
        self.name = name
        self.avatarSystemName = avatarSystemName
        self.iconColor = iconColor
        self.subtitle = subtitle
        self.date = date
        self.isPinned = isPinned
        self.greeting = greeting
        self.avatarData = avatarData
    }
}



