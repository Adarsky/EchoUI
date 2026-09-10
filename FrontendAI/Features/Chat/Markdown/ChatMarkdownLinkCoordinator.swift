import SwiftUI

@MainActor
final class ChatMarkdownLinkCoordinator: NSObject, UITextViewDelegate {
    var openURL: OpenURLAction
    var lastText: AttributedString?
    var lastFont: Font.Resolved?
    var lastColor: Color.Resolved?
    var lastColorScheme: ColorScheme?
    var lastContrast: ColorSchemeContrast?

    init(openURL: OpenURLAction) {
        self.openURL = openURL
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content else { return nil }
        return UIAction { [weak self] _ in
            self?.openURL(url)
        }
    }

    func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
        guard case .link(let url) = textItem.content else { return nil }
        let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = url.absoluteString
        }
        // No web preview or default Open action: a hold only exposes the URL and Copy.
        return UITextItem.MenuConfiguration(preview: nil, menu: UIMenu(title: url.absoluteString, children: [copy]))
    }
}
