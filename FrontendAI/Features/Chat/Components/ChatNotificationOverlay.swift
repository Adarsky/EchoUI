import SwiftUI

struct ChatNotificationOverlay: View {
    @Binding var notification: ChatNotification?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        ZStack(alignment: .top) {
            if let notification {
                ChatNotificationBanner(notification: notification, dismiss: dismiss)
                    .id(notification.id)
                    .transition(transition)
                    .zIndex(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        // Keep the animation local so replacing messages during branching doesn't animate the chat layout.
        .animation(
            reduceMotion ? .easeOut(duration: 0.18) : .spring(duration: 0.38, bounce: 0.12),
            value: notification?.id
        )
        .sensoryFeedback(trigger: notification?.id) { _, _ in
            guard let notification else { return nil }
            return notification.kind == .success ? .success : .warning
        }
        .task(id: notification?.id) {
            await announceAndDismiss()
        }
    }

    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .offset(y: -12)
                .combined(with: .scale(scale: 0.97, anchor: .top))
                .combined(with: .opacity),
            removal: .offset(y: -6)
                .combined(with: .opacity)
                .animation(.easeOut(duration: 0.2))
        )
    }

    private func dismiss() {
        notification = nil
    }

    @MainActor
    private func announceAndDismiss() async {
        guard let presented = notification else { return }
        AccessibilityNotification.Announcement("\(presented.title). \(presented.message)").post()

        // Errors remain available to read; VoiceOver users dismiss confirmations at their own pace.
        guard presented.kind == .success, !voiceOverEnabled else { return }
        do {
            try await Task.sleep(for: .seconds(3))
        } catch {
            return
        }
        guard !Task.isCancelled, notification?.id == presented.id else { return }
        dismiss()
    }
}
