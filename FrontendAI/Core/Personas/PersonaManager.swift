import Foundation
import SwiftData

@Observable
class PersonaManager {
    private static let storageKey = "activePersonaID"
    private let defaults: UserDefaults

    // SwiftData model instances are context-bound. Keep only the identity so each
    // screen resolves the latest model from its own query before building a request.
    private(set) var activePersonaID: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.activePersonaID = defaults
            .string(forKey: Self.storageKey)
            .flatMap(UUID.init(uuidString:))
    }

    func selectPersona(_ persona: PersonaModel?) {
        setActivePersonaID(persona?.id)
    }

    func activePersona(from allPersonas: [PersonaModel]) -> PersonaModel? {
        guard let activePersonaID else { return nil }
        return allPersonas.first { $0.id == activePersonaID }
    }

    func restoreActivePersona(from allPersonas: [PersonaModel]) {
        guard let activePersonaID else { return }
        if !allPersonas.contains(where: { $0.id == activePersonaID }) {
            setActivePersonaID(nil)
        }
    }

    private func setActivePersonaID(_ id: UUID?) {
        activePersonaID = id

        if let id {
            defaults.set(id.uuidString, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }
}
