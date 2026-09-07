import SwiftUI

struct UsageShareBar: View {
    let share: Double
    var tint: Color = UsageStyle.accent

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * min(max(share, 0), 1))
                }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
