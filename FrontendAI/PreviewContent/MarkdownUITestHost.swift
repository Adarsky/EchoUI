#if DEBUG
import SwiftUI

/// A deterministic streaming message exercises the production renderer without an API.
struct MarkdownUITestHost: View {
    @StateObject private var message = ChatMessageModel(content: "# Live Markdown\n\n**Formatted while streaming**", isUser: false)

    var body: some View {
        NavigationStack {
            ScrollView {
                MessageRow(msg: message, availableWidth: 350, regenerate: { _ in },
                           switchVariant: { _, _ in }, onDelete: { _ in })
                    .padding(12)
            }
            .navigationTitle("Markdown")
            .toolbar {
                Button("Append", action: appendSample)
                    .accessibilityIdentifier("markdown.append")
            }
        }
        .onAppear { message.setStreaming(true) }
    }

    private func appendSample() {
        message.appendChunk("""


        ## Blocks

        *Italic*, ~~deleted~~, `inline code`, and [a link](https://example.com).

        > A quote with **emphasis**.
        > - A nested list

        - [x] Completed task
        - [ ] Pending task

        3. Third item
        4. Fourth item

        | Feature | Status |
        | :--- | ---: |
        | Markdown | Ready |
        | Streaming | Live |

        ---

        ```swift
        let newline = "\\n"
        let path = "/new/notes"
        ```
        """, to: 0)
    }
}
#endif
