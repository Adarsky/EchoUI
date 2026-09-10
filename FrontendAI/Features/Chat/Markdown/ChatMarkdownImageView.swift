import SwiftUI

struct ChatMarkdownImageView: View {
    let url: URL
    let alternative: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .accessibilityLabel(alternative.isEmpty ? "Image" : alternative)
            } else {
                Link(destination: url) {
                    Label(alternative.isEmpty ? "Image" : alternative, systemImage: "photo")
                }
            }
        }
        .task(id: url) { await loadImage() }
    }

    private func loadImage() async {
        image = nil
        let loaded = try? await ChatMarkdownImageLoader.shared.image(at: url)
        guard !Task.isCancelled else { return }
        image = loaded
    }
}
