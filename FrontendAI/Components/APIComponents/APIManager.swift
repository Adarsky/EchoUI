//
//  APIManager.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


import Foundation
import SwiftData

@MainActor
class APIManager: ObservableObject {
    @Published var selectedServer: APIServer?

    init(selectedServer: APIServer? = nil) {
        self.selectedServer = selectedServer
    }
}
