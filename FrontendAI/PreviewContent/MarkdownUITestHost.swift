#if DEBUG
import SwiftUI

/// A deterministic streaming message exercises the production renderer without an API.
struct MarkdownUITestHost: View {
    @StateObject private var message: ChatMessageModel
    @State private var openedURL = "Nothing opened"
    @State private var copiedURL = "Nothing copied"

    private let testsLinks = ProcessInfo.processInfo.arguments.contains("--markdown-links-ui-testing")

    init() {
        let testsLinks = ProcessInfo.processInfo.arguments.contains("--markdown-links-ui-testing")
        let content = testsLinks
            ? "# Links\n\nVisit [first site](https://example.com/first?one=1&two=2) or [second site](https://example.org/second).\n\n**Bold**, *italic*, and `code` beside [another link](https://example.net)."
            : "# Live Markdown\n\n**Formatted while streaming**"
        _message = StateObject(wrappedValue: ChatMessageModel(content: content, isUser: false))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                MessageRow(msg: message, availableWidth: 350, regenerate: { _ in },
                           switchVariant: { _, _ in }, onDelete: { _ in })
                    .padding(12)
                if testsLinks {
                    Text(openedURL).accessibilityIdentifier("markdown.opened-url")
                    Text(copiedURL).accessibilityIdentifier("markdown.copied-url")
                }
            }
            .navigationTitle("Markdown")
            .toolbar {
                Button("Append", action: appendSample)
                    .accessibilityIdentifier("markdown.append")
                if testsLinks {
                    Button("Read Clipboard") { copiedURL = UIPasteboard.general.string ?? "Empty" }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            openedURL = url.absoluteString
            return .handled
        })
        .onAppear {
            if testsLinks {
                // Native context-menu animations can keep XCTest waiting for quiescence.
                // This affects only the dedicated debug fixture, never the chat screen.
                UIView.setAnimationsEnabled(false)
            }
            message.setStreaming(true)
        }
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
