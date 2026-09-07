import SwiftUI

struct OrphanedCacheDetailView: View {
    let row: CacheRow

    var body: some View {
        List {
            Section {
                UsageHero(
                    eyebrow: "Saved conversations", value: CacheByteFormatter.string(for: row.byteCount),
                    description: "These chats belong to a character that has been deleted.",
                    systemImage: "archivebox"
                )
                .listRowInsets(UsageStyle.rowInsets)
            }
            Section {
                ForEach(row.histories.sorted { $0.date > $1.date }) { history in
                    VStack(alignment: .leading, spacing: UsageStyle.compactSpacing) {
                        Text(history.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text("\(history.messages.count.formatted()) messages · \(CacheByteFormatter.string(for: CacheEstimator.estimatedByteCount(for: history)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(UsageStyle.rowInsets)
                }
            } header: {
                UsageSectionHeading(title: "Saved chats", subtitle: "Most recent first")
            }
        }
        .navigationTitle(row.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
