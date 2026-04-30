import SwiftUI

struct ChatListRow: View {
    let title: String
    let subtitle: String
    let date: String
    let isPinned: Bool
    let avatarImage: Image

    var body: some View {
        HStack(spacing: 12) {
            avatarImage
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(singleLineSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
            
            VStack {
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(height: 40)
    }

    private var singleLineSubtitle: String {
        subtitle
            .components(separatedBy: .newlines)
            .joined(separator: " ")
    }
}

#Preview("Chat Row") {
    List {
        ChatListRow(
            title: "Travel Planner",
            subtitle: "You: Find a quiet hotel near the old town. Find a quiet hotel near the old town",
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
