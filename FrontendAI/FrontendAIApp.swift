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

        let modelConfiguration = ModelConfiguration(
            "FrontendAI",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let storeURL = modelConfiguration.url

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Recovery path for incompatible stores after schema changes.
            // We recreate only when container initialization fails.
            print("⚠️ SwiftData load failed: \(error). Attempting store reset.")

            do {
                try resetStore(at: storeURL)
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Не удалось создать ModelContainer после сброса хранилища: \(error)")
            }
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

private func resetStore(at storeURL: URL) throws {
    let fileManager = FileManager.default
    let paths = [
        storeURL.path,
        storeURL.path + "-shm",
        storeURL.path + "-wal"
    ]

    for path in paths where fileManager.fileExists(atPath: path) {
        try fileManager.removeItem(atPath: path)
    }
}
