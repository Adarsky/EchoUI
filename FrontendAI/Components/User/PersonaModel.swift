//
//  PersonaModel.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//


import Foundation
import SwiftData
import SwiftUI

@Model
class PersonaModel: Identifiable  {
    var id: UUID
    var name: String
    var systemPrompt: String
    var avatarSystemName: String
    var iconColorName: String
    var avatarData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        systemPrompt: String,
        avatarSystemName: String,
        iconColorName: String,
        avatarData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.avatarSystemName = avatarSystemName
        self.iconColorName = iconColorName
        self.avatarData = avatarData
    }

    var iconColor: Color {
        Color(iconColorName)
    }

    var avatarImage: Image {
        if let data = avatarData, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        } else {
            return Image(systemName: avatarSystemName)
        }
    }
}
