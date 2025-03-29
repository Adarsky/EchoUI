//
//  APIConfiguration.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


import Foundation

struct APIConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var baseURL: String
    var selectedModel: String
    var availableModels: [String]
    var temperature: Double
    var isOnline: Bool = false
}
