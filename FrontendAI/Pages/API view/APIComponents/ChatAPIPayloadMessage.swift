//
//  ChatAPIPayloadMessage.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//

import Foundation

struct ChatPayloadMessage: Codable {
    let role: String
    let content: String
}
