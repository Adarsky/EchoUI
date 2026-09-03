import SwiftUI

struct ErrorMessage: View {
    let failure: ChatReplyFailure
    let isRetryDisabled: Bool
    let retry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var symbolAnimationTrigger = 0

    init(
        failure: ChatReplyFailure,
        isRetryDisabled: Bool = false,
        retry: @escaping () -> Void
    ) {
        self.failure = failure
        self.isRetryDisabled = isRetryDisabled
        self.retry = retry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack(alignment: .top, spacing: Layout.headerSpacing) {
                Image(systemName: failure.systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.red)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .background(.red.opacity(Layout.iconBackgroundOpacity), in: .circle)
                    .symbolEffect(.bounce, value: symbolAnimationTrigger)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Layout.textSpacing) {
                    Text(failure.title)
                        .font(.headline)
                        .bold()

                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: Layout.minimumTapHeight)
            }
            .glassEffect(.regular.tint(.red.opacity(0.8)).interactive())
            .buttonBorderShape(.capsule)
            .disabled(isRetryDisabled)
            .accessibilityHint("Retries generating this response")
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(.red.opacity(Layout.cardTintOpacity)),
            in: .rect(cornerRadius: Layout.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(.red.opacity(Layout.borderOpacity), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .onAppear(perform: animateSymbolIfNeeded)
    }

    static func appearanceAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(duration: 0.5, bounce: 0.14)
    }

    static func appearanceTransition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .opacity.combined(
                with: .scale(scale: 0.96, anchor: .topLeading)
            ),
            removal: .opacity.combined(
                with: .scale(scale: 0.98, anchor: .topLeading)
            )
        )
    }

    private func animateSymbolIfNeeded() {
        guard !reduceMotion else { return }
        symbolAnimationTrigger += 1
    }

    private enum Layout {
        static let sectionSpacing: CGFloat = 16
        static let headerSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 4
        static let cardPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 24
        static let iconSize: CGFloat = 44
        static let minimumTapHeight: CGFloat = 44
        static let iconBackgroundOpacity = 0.12
        static let cardTintOpacity = 0.035
        static let borderOpacity = 0.16
    }
}

#if DEBUG
#Preview("Animated Error Card") {
    ErrorMessageAnimationPreview()
}

#Preview("Generating Reply → Error") {
    GeneratingMessageErrorPreview()
}
#endif
