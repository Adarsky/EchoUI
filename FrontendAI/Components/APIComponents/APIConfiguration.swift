//
//  APIConfiguration.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//

import Foundation
import SwiftData

enum APIType: String, Codable, CaseIterable {
    case openai
    case openrouter
}

@Model
final class APIServer {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var baseURL: String
    var selectedModel: String
    var availableModels: [String]
    var type: APIType
    var isOnline: Bool
    var apiKey: String?
    
    init(
        uuid: UUID = UUID(),
        name: String,
        baseURL: String,
        selectedModel: String,
        availableModels: [String] = [],
        type: APIType,
        isOnline: Bool = false,
        apiKey: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.availableModels = availableModels
        self.type = type
        self.isOnline = isOnline
        self.apiKey = apiKey
    }
}
