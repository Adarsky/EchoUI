import SwiftUI

struct ChatMarkdownCodeView: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let language, !language.isEmpty {
                    Text(language).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Copy code", systemImage: "doc.on.doc", action: copyCode)
                    .labelStyle(.iconOnly)
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("markdown.copy-code")
            }
            ScrollView(.horizontal) {
                Text(verbatim: code)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(.primary.opacity(0.06), in: .rect(cornerRadius: 8))
    }

    private func copyCode() {
        UIPasteboard.general.string = code
    }
}
