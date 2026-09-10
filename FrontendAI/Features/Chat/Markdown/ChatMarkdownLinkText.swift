import SwiftUI

/// TextKit provides per-link hit testing and native menus, including wrapped links.
/// Only paragraphs containing links use this bridge; unchanged text keeps its layout.
struct ChatMarkdownLinkText: UIViewRepresentable {
    let text: AttributedString
    @Environment(\.openURL) private var openURL
    @Environment(\.chatMarkdownTextColor) private var textColor

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: true)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = false // Resolved from SwiftUI's Dynamic Type environment.
        view.dataDetectorTypes = []
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.openURL = openURL
        let font = context.environment.font ?? .body
        let resolvedFont = font.resolve(in: context.environment.fontResolutionContext)
        let resolvedColor = textColor.resolve(in: context.environment)
        guard context.coordinator.lastText != text || context.coordinator.lastFont != resolvedFont
                || context.coordinator.lastColor != resolvedColor
                || context.coordinator.lastColorScheme != context.environment.colorScheme
                || context.coordinator.lastContrast != context.environment.colorSchemeContrast else { return }
        context.coordinator.lastText = text
        context.coordinator.lastFont = resolvedFont
        context.coordinator.lastColor = resolvedColor
        context.coordinator.lastColorScheme = context.environment.colorScheme
        context.coordinator.lastContrast = context.environment.colorSchemeContrast
        view.attributedText = ChatMarkdownLinkTextStyle.attributedText(
            text, environment: context.environment, textColor: textColor
        )
        view.linkTextAttributes = [.foregroundColor: UIColor.tintColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    func makeCoordinator() -> ChatMarkdownLinkCoordinator {
        ChatMarkdownLinkCoordinator(openURL: openURL)
    }
}
