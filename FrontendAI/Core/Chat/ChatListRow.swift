import SwiftUI
import Foundation

struct ChatListRow: View {
    let title: String
    let subtitle: String
    let date: String
    let isPinned: Bool
    let draft: String?
    let avatarImage: Image

    init(
        title: String,
        subtitle: String,
        date: String,
        isPinned: Bool,
        draft: String? = nil,
        avatarImage: Image
    ) {
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.isPinned = isPinned
        self.draft = draft
        self.avatarImage = avatarImage
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarImage
                .resizable()
                .scaledToFill()
                .frame(width: 55, height: 55)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
                if let displayedDraft {
                    Text("Draft: \(displayedDraft)")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                } else {
                    Text(renderedChatListSubtitle(from: singleLineSubtitle))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .trailing) {
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxHeight: .infinity, alignment: .topTrailing)

                if isPinned {
                    Image(systemName: "heart.fill")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .frame(maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(maxHeight: .infinity, alignment: .trailing)
        }
        .frame(height: 70)
    }

    private var singleLineSubtitle: String {
        subtitle
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private var displayedDraft: String? {
        guard let draft,
              !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return draft
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

private func renderedChatListSubtitle(from text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
}

#Preview("Chat Row") {
    List {
        ChatListRow(
            title: "Travel Planner",
            subtitle: "You: Find a **quiet** hotel near the *old town*. Find a quiet hotel near the old town",
            date: "Apr 28",
            isPinned: false,
            avatarImage: Image(systemName: "airplane.departure")
        )
    }
    .listStyle(.plain)
}

#Preview("Pinned Chat Row") {
    List {
        ChatListRow(
            title: "Swift Mentor",
            subtitle: "Swift Mentor: Use a small persisted sort index. Use a small persisted sort index.",
            date: "Apr 27",
            isPinned: true,
            avatarImage: Image(systemName: "swift")
        )
    }
    .listStyle(.plain)
}

#Preview("Chat Rows") {
    List {
        ChatListRow(
            title: "Design Lead",
            subtitle: "Design Lead: Keep the pinned section scannable.",
            date: "Apr 28",
            isPinned: true,
            avatarImage: Image(systemName: "paintpalette.fill")
        )

        ChatListRow(
            title: "API Helper",
            subtitle: "You: Check why the streaming endpoint retries.",
            date: "Apr 24",
            isPinned: false,
            avatarImage: Image(systemName: "network")
        )
    }
    .listStyle(.plain)
}
