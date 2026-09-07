import SwiftUI
import SwiftData

struct CacheView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]
    @State private var rowPendingDeletion: CacheRow?
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingClearAllConfirmation = false
    @State private var deletionError: String?
    @State private var isShowingDeletionError = false

    var body: some View {
        let rows = CacheRow.makeRows(bots: bots, histories: histories)
        let totalBytes = rows.reduce(0) { $0 + $1.byteCount }
        let totalMessages = rows.reduce(0) { $0 + $1.messageCount }

        List {
            Section {
                VStack(alignment: .leading, spacing: UsageStyle.spacing) {
                    UsageHero(
                        eyebrow: "On this device",
                        value: CacheByteFormatter.string(for: totalBytes),
                        description: "Estimated space used by saved conversations.",
                        systemImage: "internaldrive"
                    )
                    if !rows.isEmpty {
                        CacheDistributionView(rows: rows)
                        Divider()
                        UsageMetricPair(
                            firstTitle: "Saved chats", firstValue: histories.count.formatted(),
                            secondTitle: "Messages", secondValue: totalMessages.formatted()
                        )
                    }
                }
                .listRowInsets(UsageStyle.rowInsets)
            } footer: {
                Text("Includes message text and saved reply variants. Images, app files, and database overhead are excluded.")
            }

            if rows.isEmpty {
                ContentUnavailableView(
                    "No Saved Chats", systemImage: "tray",
                    description: Text("Your storage breakdown will appear after you start a conversation.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(rows) { row in
                        NavigationLink {
                            if let bot = row.bot {
                                ChatHistoryListView(botID: bot.id, botName: bot.name)
                            } else {
                                OrphanedCacheDetailView(row: row)
                            }
                        } label: {
                            UsageCharacterRow(
                                bot: row.bot, title: row.title,
                                value: CacheByteFormatter.string(for: row.byteCount),
                                detail: "\(row.historyCount.formatted()) chats · \(row.percentText) of storage",
                                share: row.share
                            )
                        }
                        .listRowInsets(UsageStyle.rowInsets)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                rowPendingDeletion = row
                                isShowingDeleteConfirmation = true
                            }
                        }
                    }
                } header: {
                    UsageSectionHeading(title: "Storage by character", subtitle: "Largest first · Tap to explore saved chats")
                }

                Section {
                    Button("Delete All Saved Chats", systemImage: "trash", role: .destructive) {
                        isShowingClearAllConfirmation = true
                    }
                    .frame(minHeight: 44)
                } footer: {
                    Text("Permanently removes conversations. Characters, personas, and API settings are kept.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, UsageStyle.spacing, for: .scrollContent)
        .navigationTitle("Storage Usage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete saved chats?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteSelectedHistories)
            Button("Cancel", role: .cancel) { rowPendingDeletion = nil }
        } message: {
            Text("This permanently removes saved histories for \(rowPendingDeletion?.title ?? "this character"). The character itself is kept.")
        }
        .alert("Delete all saved chats?", isPresented: $isShowingClearAllConfirmation) {
            Button("Delete All", role: .destructive, action: deleteAllHistories)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes all saved chat histories. Characters, personas, and API settings are kept.")
        }
        .alert("Could Not Delete Chats", isPresented: $isShowingDeletionError) { } message: {
            Text(deletionError ?? "Please try again.")
        }
    }

    private func deleteSelectedHistories() {
        guard let rowPendingDeletion else { return }
        for history in rowPendingDeletion.histories {
            ChatHistoryPersistence.delete(history, context: modelContext)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
            isShowingDeletionError = true
        }
        self.rowPendingDeletion = nil
    }

    private func deleteAllHistories() {
        do {
            try ChatHistoryPersistence.deleteAllHistoriesAndMessages(context: modelContext)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
            isShowingDeletionError = true
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CacheView()
    }
    .modelContainer(UsagePreviewData.container)
}

#Preview("Empty") {
    NavigationStack {
        CacheView()
    }
    .modelContainer(UsagePreviewData.makeContainer(empty: true))
}

#endif
