import SwiftUI

struct ChatScreenView: View {
    let model: ChatScreenModel
    let bindings: ChatScreenBindings
    let actions: ChatScreenActions

    @State private var autoScrollState = ChatAutoScrollState()
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var pendingBottomScroll = false

    private static let bottomAnchorID = "chat-screen-bottom-anchor"

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    ChatMessageStack(
                        messages: model.messages,
                        botName: model.botName,
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
                .defaultScrollAnchor(.bottom, for: .alignment)
                .scrollDismissesKeyboard(.interactively)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    ChatComposerDock(
                        composer: model.composer,
                        bindings: bindings,
                        actions: actions.composer
                    )
                }
                .onScrollGeometryChange(for: ChatScrollMetrics.self) { geometry in
                    ChatScrollMetrics(geometry: geometry)
                } action: { previous, current in
                    updateAutoScrollState(from: previous, to: current)
                }
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                }
                .onAppear {
                    scheduleScrollToBottom(proxy, animated: false, force: true)
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
    }

    private func messageWidth(in geometry: GeometryProxy) -> CGFloat {
        max(1, geometry.size.width - ChatScreenLayout.horizontalInset * 2)
    }

    private func topContentPadding(in geometry: GeometryProxy) -> CGFloat {
        geometry.safeAreaInsets.top + ChatScreenLayout.topContentSpacing
    }

    private func shouldFollowMessageChange(_ message: ChatMessageModel) -> Bool {
        shouldAutoScroll && message.id == model.messages.last?.id
    }

    private var shouldAutoScroll: Bool {
        autoScrollState.isFollowing && !isUserScrolling
    }

    private var isUserScrolling: Bool {
        switch scrollPhase {
        case .tracking, .interacting, .decelerating:
            true
        case .idle, .animating:
            false
        }
    }

    private func updateAutoScrollState(from previous: ChatScrollMetrics, to current: ChatScrollMetrics) {
        autoScrollState.update(
            from: previous,
            to: current,
            isUserScrolling: isUserScrolling,
            bottomThreshold: ChatScreenLayout.bottomStickinessThreshold
        )
    }

    private func scheduleScrollToBottom(_ proxy: ScrollViewProxy, animated: Bool, force: Bool = false) {
        guard force || shouldAutoScroll else { return }
        guard !pendingBottomScroll else { return }
        pendingBottomScroll = true

        DispatchQueue.main.async {
            pendingBottomScroll = false
            guard force || shouldAutoScroll else { return }

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
    let botName: String
    let availableWidth: CGFloat
    let actions: ChatScreenActions.Messages
    let onMessageChange: (ChatMessageModel) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: ChatScreenLayout.messageSpacing) {
            ForEach(messages) { message in
                MessageRow(
                    msg: message,
                    availableWidth: availableWidth,
                    botName: botName,
                    regenerate: actions.regenerate,
                    switchVariant: actions.switchVariant,
                    onEdit: actions.edit,
                    onDelete: actions.delete,
                    onBranch: actions.branch
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
        ChatInputBarHost(
            inputBar: ChatInputBar(
                inputText: bindings.inputText,
                isGenerating: composer.isGenerating,
                isThinking: composer.isThinking,
                sendButtonStyle: composer.sendButtonStyle,
                placeholder: composer.placeholder,
                onSend: actions.send,
                onStop: actions.stop
            )
        )
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, ChatScreenLayout.composerVerticalPadding)
    }
}

private enum ChatScreenLayout {
    static let horizontalInset: CGFloat = 15
    static let messageSpacing: CGFloat = 12
    static let topContentSpacing: CGFloat = 12
    static let bottomContentPadding: CGFloat = 8
    static let composerVerticalPadding: CGFloat = 8
    static let bottomStickinessThreshold: CGFloat = 24
    static let scrollAnimationDuration: TimeInterval = 0.22
}
