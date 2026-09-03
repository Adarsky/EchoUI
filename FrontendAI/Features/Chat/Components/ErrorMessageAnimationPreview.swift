#if DEBUG
import SwiftUI

struct ErrorMessageAnimationPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsError = false
    @State private var replayID = 0

    private let failure = ChatReplyFailure(
        kind: .connectionInterrupted,
        message: "The connection dropped while the reply was being generated."
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Error animation")
                    .font(.title3)
                    .bold()

                Text("The preview plays automatically. Use replay to inspect the transition again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if showsError {
                    ErrorMessage(failure: failure, retry: replayAnimation)
                        .transition(
                            ErrorMessage.appearanceTransition(reduceMotion: reduceMotion)
                        )
                } else {
                    Label("Waiting for the simulated failure…", systemImage: "ellipsis.message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 440, minHeight: 210, alignment: .topLeading)

            Button(
                "Replay Animation",
                systemImage: "arrow.counterclockwise",
                action: replayAnimation
            )
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .frame(minHeight: 44)
            .accessibilityHint("Hides and presents the error card again")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(
            ErrorMessage.appearanceAnimation(reduceMotion: reduceMotion),
            value: showsError
        )
        .task(id: replayID) {
            await playAnimation()
        }
    }

    private func replayAnimation() {
        replayID &+= 1
    }

    @MainActor
    private func playAnimation() async {
        showsError = false

        do {
            try await Task.sleep(for: .milliseconds(450))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        showsError = true
    }
}
#endif
