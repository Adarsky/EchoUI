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


    @State private var histories: [ChatHistory] = []

    private enum HistoryBucket: String, CaseIterable, Identifiable {
        case last3Days = "Last 3 Days"
        case thisWeek = "This Week"
        case lastMonth = "Last Month"
        case moreThanMonthAgo = "More Than a Month Ago"

        var id: String { rawValue }
    }

    private struct SectionGroup: Identifiable {
        let bucket: HistoryBucket
        let items: [ChatHistory]

        var id: String { bucket.id }
        var title: String { bucket.rawValue }
    }

    var body: some View {
        ScrollView {
            if histories.isEmpty {
                Text("No history found for \(botName).")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                    ForEach(sectionedHistories) { section in
                        Section {
                            ForEach(section.items) { history in
                                Button {
                                    onSelectHistory?(history)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(displayDate(for: history).formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Text(lastMessageText(for: history))
                                            .font(.body)
                                            .lineLimit(1)

                                        Text("\(history.messages.count) messages")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.clear))
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteHistory(history)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("\(botName) History")
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
                let fetched = try modelContext.fetch(descriptor)
                histories = fetched.sorted { displayDate(for: $0) > displayDate(for: $1) }
                print("Loaded \(histories.count) histories")
            } catch {
                print("❌ Failed to load histories: \(error)")
            }
        }
    }

    private var sectionedHistories: [SectionGroup] {
        var grouped: [HistoryBucket: [ChatHistory]] = [:]
        for bucket in HistoryBucket.allCases {
            grouped[bucket] = []
        }

        for history in histories {
            let bucket = bucket(for: displayDate(for: history))
            grouped[bucket, default: []].append(history)
        }

        return HistoryBucket.allCases.compactMap { bucket in
            guard let items = grouped[bucket], !items.isEmpty else { return nil }
            return SectionGroup(bucket: bucket, items: items)
        }
    }

    private func bucket(for date: Date) -> HistoryBucket {
        let calendar = Calendar.current
        let now = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        if date >= threeDaysAgo {
            return .last3Days
        }
        if date >= weekAgo {
            return .thisWeek
        }
        if date >= monthAgo {
            return .lastMonth
        }
        return .moreThanMonthAgo
    }

    private func displayDate(for history: ChatHistory) -> Date {
        let lastMessage = history.messages
            .sorted(by: { $0.index < $1.index })
            .last
        return lastMessage?.timestamp ?? history.date
    }

    private func deleteHistory(_ history: ChatHistory) {
        modelContext.delete(history)
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

#Preview("Temple Chats") {
    NavigationStack {
        ChatHistoryListView(
            botID: templePreviewBotID,
            botName: "Temple Guide"
        )
    }
    .modelContainer(templeChatHistoryPreviewContainer)
}

private let templePreviewBotID = UUID(uuidString: "E6C3D6D3-B9D8-4E2A-9AAE-7A6E8A5B7D19")!

@MainActor
private let templeChatHistoryPreviewContainer: ModelContainer = {
    let schema = Schema([BotModel.self, ChatHistory.self, ChatMessageEntity.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext

    let bot = BotModel(
        id: templePreviewBotID,
        name: "Temple Guide",
        subtitle: "Ancient sites and stories",
        date: "11.03.2026",
        avatarSystemName: "building.columns.fill",
        iconColorName: "orange",
        isPinned: true,
        greeting: "Ask me about temples, rituals, and travel routes."
    )
    context.insert(bot)

    let calendar = Calendar.current
    let now = Date()

    let templePrompts: [String] = [
        "Opening hours for the hill temple?",
        "What should I wear for morning prayer?",
        "Best route between the river shrine and old pagoda?",
        "Which temple has the oldest mural?",
        "Any etiquette for photography inside sanctuaries?",
        "Can I attend the evening lamp ceremony?",
        "Quietest time to visit the lotus temple?",
        "Recommended temples for a half-day walk?",
        "Where can I leave shoes near the main gate?",
        "What offerings are appropriate for first-time visitors?"
    ]

    let templeReplies: [String] = [
        "It opens at 6:00 AM and closes after sunset, around 7:15 PM this season.",
        "Use covered shoulders and knees, and carry a light scarf for shrine halls.",
        "Start at the riverside shrine, then take East Stone Road to avoid steep stairs.",
        "The western sanctuary houses murals from the 14th century restoration period.",
        "Photos are allowed in courtyards, but disable flash inside prayer chambers.",
        "Yes, visitors may watch quietly from the outer ring after 6:30 PM.",
        "Arrive between 7:00 and 8:00 AM for fewer crowds and cooler weather.",
        "Try the bell tower, moon court, and cedar hall in that order.",
        "Use the free shelves by Gate C; attendants can provide a token.",
        "Flowers, fruit, or incense are welcome. Keep offerings simple and respectful."
    ]

    let totalChats = 36
    for i in 0..<totalChats {
        let daysAgo: Int
        switch i {
        case 0..<12:
            daysAgo = i % 3
        case 12..<22:
            daysAgo = 3 + (i - 12) % 4
        case 22..<30:
            daysAgo = 8 + (i - 22) * 2
        default:
            daysAgo = 40 + (i - 30) * 9
        }

        let chatDate = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let prompt = templePrompts[i % templePrompts.count]
        let reply = templeReplies[i % templeReplies.count]

        let messages = [
            ChatMessageEntity(
                text: "\(prompt) (Trip #\(i + 1))",
                isUser: true,
                index: 0,
                timestamp: calendar.date(byAdding: .minute, value: -8, to: chatDate)
            ),
            ChatMessageEntity(
                text: reply,
                isUser: false,
                index: 1,
                timestamp: calendar.date(byAdding: .minute, value: -7, to: chatDate)
            ),
            ChatMessageEntity(
                text: "Any nearby tea house after that?",
                isUser: true,
                index: 2,
                timestamp: calendar.date(byAdding: .minute, value: -4, to: chatDate)
            ),
            ChatMessageEntity(
                text: "Yes, Cedar Tea Room is a 5-minute walk from the south exit.",
                isUser: false,
                index: 3,
                timestamp: chatDate
            )
        ]

        context.insert(ChatHistory(messages: messages, date: chatDate, bot: bot))
    }

    try? context.save()
    return container
}()
