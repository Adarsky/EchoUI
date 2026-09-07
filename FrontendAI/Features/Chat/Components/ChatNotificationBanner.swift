import SwiftUI

struct ChatNotificationBanner: View {
    let notification: ChatNotification
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var iconSize = 38

    private var accent: Color {
        notification.kind == .success ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.kind == .success ? "arrow.triangle.branch" : "exclamationmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: iconSize, height: iconSize)
                .background(accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button("Dismiss notification", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 14)
        .frame(maxWidth: 440)
        .background {
            let shape = RoundedRectangle(cornerRadius: 26)
            if reduceTransparency {
                shape.fill(.background)
            } else {
                shape.fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
        .accessibilityIdentifier("chat-notification")
        .accessibilityAction(.escape, dismiss)
    }
}

#Preview("Branch confirmation") {
    ChatNotificationBanner(notification: .branched, dismiss: {})
        .padding()
}

#Preview("Save error · Dark") {
    ChatNotificationBanner(
        notification: .error(
            "Couldn’t save chat",
            message: "Your current messages remain open so you can try again."
        ),
        dismiss: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
