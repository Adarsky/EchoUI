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
    var onSelectHistory: ((ChatHistory) -> Void)? = nil

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
                    Button {
                        onSelectHistory?(history)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(history.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(lastMessageText(for: history))
                                .font(.body)
                                .lineLimit(1)

                            Text("\(history.messages.count) messages")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteHistory)
            }
        }
        .navigationTitle("\(botName) History")
        .toolbar {
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
            loadHistory()
        } catch {
            print("Error saving model context after deletion: \(error)")
        }
    }
    
    private func lastMessageText(for history: ChatHistory) -> String {
        guard let last = history.messages
            .sorted(by: { $0.index < $1.index })
            .last
        else {
            return "Empty chat"
        }

        let prefix = last.isUser ? "You: " : "\(botName): "
        let full = prefix + last.text
        return full.count > 80 ? String(full.prefix(80)) + "…" : full
    }
}


