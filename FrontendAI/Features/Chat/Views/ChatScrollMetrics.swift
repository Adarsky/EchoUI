import SwiftUI

struct ChatScrollMetrics: Equatable {
    let visibleTop: CGFloat
    let distanceToBottom: CGFloat

    init(visibleTop: CGFloat, distanceToBottom: CGFloat) {
        self.visibleTop = visibleTop
        self.distanceToBottom = max(0, distanceToBottom)
    }

    init(geometry: ScrollGeometry) {
        let scrollableBottom = geometry.contentSize.height + geometry.contentInsets.bottom

        self.init(
            visibleTop: geometry.visibleRect.minY,
            distanceToBottom: scrollableBottom - geometry.visibleRect.maxY
        )
    }

    func isNearBottom(within threshold: CGFloat) -> Bool {
        distanceToBottom <= threshold
    }
}
