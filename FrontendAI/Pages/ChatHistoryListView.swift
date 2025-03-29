//
//  ChatHistoryListView.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//

import SwiftUI
import SwiftData

struct ChatHistoryListView: View {
    let botID: UUID
    let botName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PersonaManager.self) var personaManager


    @State private var histories: [ChatHistory] = []

    var body: some View {
        List {
            if histories.isEmpty {
                Text("No history found for \(botName).")
                    .foregroundColor(.secondary)
            } else {
                ForEach(histories) { history in
                    NavigationLink {
                        ChatHistoryDetailView(history: history)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(history.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(history.messages.first?.text ?? "Empty chat")
                                .font(.body)
                                .lineLimit(1)

                            Text("\(history.messages.count) messages")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: deleteHistory)
            }
        }
        .navigationTitle("\(botName) History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            loadHistory()
        }
    }

    private func loadHistory() {
        Task {
            do {
                let descriptor = FetchDescriptor<ChatHistory>(
                    predicate: #Predicate { $0.botID == botID },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                histories = try modelContext.fetch(descriptor)
                print("Loaded \(histories.count) histories")
            } catch {
                print("❌ Failed to load histories: \(error)")
            }
        }
    }

    private func deleteHistory(at offsets: IndexSet) {
        for index in offsets {
            let historyToDelete = histories[index]
            modelContext.delete(historyToDelete)
        }
        do {
            try modelContext.save()
            loadHistory() // Перезагрузим после удаления
        } catch {
            print("Error saving model context after deletion: \(error)")
        }
    }
}
