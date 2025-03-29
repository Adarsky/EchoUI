//
//  Persona.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//

import Foundation
import SwiftUI

struct Persona: Identifiable, Hashable {
    let id: UUID
    let name: String
    let avatarSystemName: String
    let iconColor: Color
    let description: String
    let avatarData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        avatarSystemName: String,
        iconColor: Color,
        description: String,
        avatarData: Data?
    ) {
        self.id = id
        self.name = name
        self.avatarSystemName = avatarSystemName
        self.iconColor = iconColor
        self.description = description
        self.avatarData = avatarData
    }
}

