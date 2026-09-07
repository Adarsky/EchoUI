import SwiftUI

/// Gives the editor its own focus system to work around safeAreaBar's iOS 26 focus issue.
struct ChatInputBarHost: UIViewControllerRepresentable {
    let inputBar: ChatInputBar

    func makeUIViewController(context: Context) -> UIHostingController<ChatInputBar> {
        let controller = UIHostingController(rootView: inputBar)
        controller.view.backgroundColor = .clear
        // The surrounding safeAreaBar handles the keyboard and device insets.
        controller.safeAreaRegions = []
        controller.sizingOptions = .intrinsicContentSize
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<ChatInputBar>, context: Context) {
        controller.rootView = inputBar
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: UIHostingController<ChatInputBar>,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return uiViewController.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
    }
}
