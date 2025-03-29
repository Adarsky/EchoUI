//
//  FrontendAIApp.swift
//  FrontendAI
//
//  Created by macbook on 25.03.2025.
//

import SwiftUI
import SwiftData

@main
struct FrontendAIApp: App {

    @StateObject var apiManager = APIManager()
    @State var personaManager = PersonaManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BotModel.self,
            APIServer.self,
            ChatHistory.self,
            ChatMessageEntity.self,
            PersonaModel.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainPage()
                .environmentObject(apiManager)
                .environment(personaManager)
                .onAppear {
                    Task {
                        let descriptor = FetchDescriptor<PersonaModel>()
                        let context = ModelContext(sharedModelContainer)
                        let allPersonas = try? context.fetch(descriptor)
                        personaManager.restoreActivePersona(from: allPersonas ?? [])
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}


