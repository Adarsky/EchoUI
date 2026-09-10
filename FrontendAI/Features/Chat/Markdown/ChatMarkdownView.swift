import SwiftUI

struct ChatMarkdownView: View {
    let blocks: [ChatMarkdownBlock]
    var fadeNewBlocks = false
    var textColor: Color = .primary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var pendingURL: URL?
    @State private var showsLinkConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                ChatMarkdownBlockView(block: block)
                    .equatable()
                    .transition(.opacity)
            }
        }
        .textSelection(.enabled)
        .environment(\.chatMarkdownTextColor, textColor)
        .environment(\.openURL, OpenURLAction(handler: confirmOpening))
        .alert("Open external link?", isPresented: $showsLinkConfirmation, presenting: pendingURL) { url in
            Button("Cancel", role: .cancel) { pendingURL = nil }
            Button("Continue") {
                pendingURL = nil
                openURL(url)
            }
        } message: { url in
            Text("This link will open outside the app. Only continue if you trust the destination.\n\n\(url.absoluteString)")
        }
        // Formatting is always present. The optional fade only runs on block insertion,
        // never for every token, and needs no timer, text copy, or compositing layer.
        .animation(fadeNewBlocks && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: blocks.count)
    }

    private func confirmOpening(_ url: URL) -> OpenURLAction.Result {
        guard ChatMarkdownParser.safeURL(url, image: false) != nil else { return .discarded }
        pendingURL = url
        showsLinkConfirmation = true
        return .handled
    }
}
