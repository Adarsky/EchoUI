//
//  PersonaManager.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//

import Foundation
import SwiftData

@Observable
class PersonaManager {
    private let storageKey = "activePersonaID"

    var activePersona: PersonaModel? {
        didSet {
            if let id = activePersona?.id.uuidString {
                UserDefaults.standard.set(id, forKey: storageKey)
            }
        }
    }

    func restoreActivePersona(from allPersonas: [PersonaModel]) {
        if let savedID = UserDefaults.standard.string(forKey: storageKey),
           let uuid = UUID(uuidString: savedID) {
            self.activePersona = allPersonas.first(where: { $0.id == uuid })
        }
    }
}

