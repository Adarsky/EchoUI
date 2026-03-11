//
//  Item.swift
//  FrontendAI
//
//  Created by macbook on 25.03.2025.
// idc what is this tbh

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
