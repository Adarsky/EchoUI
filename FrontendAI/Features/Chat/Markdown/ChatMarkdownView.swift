import SwiftUI

struct ChatMarkdownView: View {
    let blocks: [ChatMarkdownBlock]
    var fadeNewBlocks = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                ChatMarkdownBlockView(block: block)
                    .equatable()
                    .transition(.opacity)
            }
        }
        .textSelection(.enabled)
        // Formatting is always present. The optional fade only runs on block insertion,
        // never for every token, and needs no timer, text copy, or compositing layer.
        .animation(fadeNewBlocks && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: blocks.count)
    }
}
