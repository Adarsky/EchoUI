import SwiftUI

struct ChatMaterialBackground<BackgroundShape: Shape>: View {
    let material: ChatSurfaceMaterial
    let shape: BackgroundShape

    var body: some View {
        switch material {
        case .ultraThinMaterial:
            shape.fill(.ultraThinMaterial)
        case .glass:
            shape.fill(.clear)
                .glassEffect(.clear, in: shape)
        }
    }
}
