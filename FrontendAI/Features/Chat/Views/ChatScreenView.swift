import SwiftUI

struct ChatScreenView: View {
    let model: ChatScreenModel
    let bindings: ChatScreenBindings
    let actions: ChatScreenActions

    @State private var isPinnedToBottom = true
    @State private var pendingBottomScroll = false

    private static let bottomAnchorID = "chat-screen-bottom-anchor"

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    ChatMessageStack(
                        messages: model.messages,
                        availableWidth: messageWidth(in: geometry),
                        actions: actions.messages,
                        onMessageChange: { message in
                            guard shouldFollowMessageChange(message) else { return }
                            scheduleScrollToBottom(proxy, animated: false)
                        }
                    )
                    .environment(\.chatAppearance, model.appearance)
                    .padding(.horizontal, ChatScreenLayout.horizontalInset)
                    .padding(.top, topContentPadding(in: geometry))
                    .padding(.bottom, ChatScreenLayout.bottomContentPadding)

                    bottomAnchor
                }
                .coordinateSpace(name: ChatScreenLayout.scrollCoordinateSpace)
                .defaultScrollAnchor(.bottom, for: .alignment)
                .scrollDismissesKeyboard(.interactively)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ChatComposerDock(
                        composer: model.composer,
                        bindings: bindings,
                        actions: actions.composer
                    )
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    // Register the edge effect without moving the focus-driven composer into the bar host.
                    Color.clear.frame(height: 0)
                }
                .onPreferenceChange(ChatScreenBottomPreferenceKey.self) { bottomY in
                    updatePinnedState(bottomY: bottomY, viewportHeight: geometry.size.height)
                }
                .onAppear {
                    scheduleScrollToBottom(proxy, animated: false)
                }
                .onChange(of: messageIDs) { _, _ in
                    scheduleScrollToBottom(proxy, animated: true)
                }
            }
        }
    }

    private var messageIDs: [UUID] {
        model.messages.map(\.id)
    }

    private var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id(Self.bottomAnchorID)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ChatScreenBottomPreferenceKey.self,
                        value: proxy.frame(in: .named(ChatScreenLayout.scrollCoordinateSpace)).maxY
                    )
                }
            }
    }

    private func messageWidth(in geometry: GeometryProxy) -> CGFloat {
        max(1, geometry.size.width - ChatScreenLayout.horizontalInset * 2)
    }

    private func topContentPadding(in geometry: GeometryProxy) -> CGFloat {
        geometry.safeAreaInsets.top + ChatScreenLayout.topContentSpacing
    }

    private func shouldFollowMessageChange(_ message: ChatMessageModel) -> Bool {
        isPinnedToBottom && message.id == model.messages.last?.id
    }

    private func updatePinnedState(bottomY: CGFloat, viewportHeight: CGFloat) {
        let nextValue = bottomY <= viewportHeight + ChatScreenLayout.bottomStickinessThreshold
        guard isPinnedToBottom != nextValue else { return }
        isPinnedToBottom = nextValue
    }

    private func scheduleScrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard !pendingBottomScroll else { return }
        pendingBottomScroll = true

        DispatchQueue.main.async {
            pendingBottomScroll = false
            if animated {
                withAnimation(.easeOut(duration: ChatScreenLayout.scrollAnimationDuration)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
    }
}

private struct ChatMessageStack: View {
    let messages: [ChatMessageModel]
    let availableWidth: CGFloat
    let actions: ChatScreenActions.Messages
    let onMessageChange: (ChatMessageModel) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: ChatScreenLayout.messageSpacing) {
            ForEach(messages) { message in
                MessageRow(
                    msg: message,
                    availableWidth: availableWidth,
                    regenerate: actions.regenerate,
                    switchVariant: actions.switchVariant,
                    onDelete: actions.delete
                )
                .id(message.id)
                .onReceive(message.objectWillChange) { _ in
                    onMessageChange(message)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatComposerDock: View {
    let composer: ChatScreenModel.Composer
    let bindings: ChatScreenBindings
    let actions: ChatScreenActions.Composer

    var body: some View {
        ChatInputBar(
            inputText: bindings.inputText,
            isGenerating: composer.isGenerating,
            isThinking: composer.isThinking,
            sendButtonStyle: composer.sendButtonStyle,
            placeholder: composer.placeholder,
            onSend: actions.send,
            onStop: actions.stop
        )
        .padding(.vertical, ChatScreenLayout.composerVerticalPadding)
    }
}

private enum ChatScreenLayout {
    static let horizontalInset: CGFloat = 15
    static let messageSpacing: CGFloat = 12
    static let topContentSpacing: CGFloat = 12
    static let bottomContentPadding: CGFloat = 8
    static let composerVerticalPadding: CGFloat = 8
    static let bottomStickinessThreshold: CGFloat = 96
    static let scrollAnimationDuration: TimeInterval = 0.22
    static let scrollCoordinateSpace = "chat-screen-scroll"
}

private struct ChatScreenBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
