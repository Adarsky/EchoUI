import SwiftUI

struct ChatMarkdownInlineView: View {
    let parts: [ChatMarkdownInline]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parts) { part in
                if let url = part.imageURL {
                    ChatMarkdownImageView(url: url, alternative: String(part.text.characters))
                } else if part.text.runs.contains(where: { $0.link != nil }) {
                    ChatMarkdownLinkText(text: part.text)
                } else {
                    Text(part.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
