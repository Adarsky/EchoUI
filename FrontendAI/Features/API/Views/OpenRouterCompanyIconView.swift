import SwiftUI

struct OpenRouterCompanyIconView: View {
    let assetName: String
    let size: CGFloat

    init(assetName: String, size: CGFloat = 20) {
        self.assetName = assetName
        self.size = size
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            .accessibilityHidden(true)
    }
}
