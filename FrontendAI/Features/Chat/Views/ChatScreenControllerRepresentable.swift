import SwiftUI
import UIKit
import Combine

struct ChatScreenModel {
    let messages: [ChatMessageModel]
    let appearance: ChatAppearanceSnapshot
    let header: Header
    let composer: Composer

    struct Header {
        let bot: Bot
        let botID: UUID
        let chatAppearanceID: String?
        let currentChatTokenCount: Int
        let tokenWindow: Int?
        let personas: [PersonaModel]
        let currentPersona: PersonaModel?
        let globalPersona: PersonaModel?
        let hasPersonaOverride: Bool
        let apiManager: APIManager
    }

    struct Composer {
        let isGenerating: Bool
        let isThinking: Bool
        let sendButtonStyle: ChatInputBarSendButtonStyle
        let placeholder: String
    }
}

struct ChatScreenBindings {
    let inputText: Binding<String>
    let showChatBotSheet: Binding<Bool>
    let isViewingHistory: Binding<Bool>
}

struct ChatScreenActions {
    let navigation: Navigation
    let header: Header
    let messages: Messages
    let composer: Composer

    struct Navigation {
        let dismiss: () -> Void
    }

    struct Header {
        let startNewChat: () -> Void
        let selectPersona: (PersonaModel?) -> Void
        let useGlobalPersona: () -> Void
    }

    struct Messages {
        let regenerate: (ChatMessageModel) -> Void
        let switchVariant: (UUID, Int) -> Void
        let delete: (UUID) -> Void
    }

    struct Composer {
        let send: () -> Void
        let stop: () -> Void
    }
}

struct ChatScreenControllerRepresentable: UIViewControllerRepresentable {
    let model: ChatScreenModel
    let bindings: ChatScreenBindings
    let actions: ChatScreenActions

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(model: model, bindings: bindings, actions: actions)
    }
}

extension ChatScreenControllerRepresentable {
    final class Controller: UIViewController, UICollectionViewDataSourcePrefetching {
        private enum Section {
            case main
        }

        private typealias DataSource = UICollectionViewDiffableDataSource<Section, UUID>
        private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, UUID>

        private let collectionView: UICollectionView
        private let headerHost = UIHostingController(rootView: AnyView(EmptyView()))
        private let composerView = ChatComposerView()

        private var dataSource: DataSource?
        private var messages: [ChatMessageModel] = []
        private var messagesByID: [UUID: ChatMessageModel] = [:]
        private var chatAppearance = ChatAppearanceSnapshot.global()
        private var messageActions: ChatScreenActions.Messages?
        private var appliedMessageIDs: [UUID] = []
        private var messageCancellables: [UUID: AnyCancellable] = [:]
        private var pendingObservedInvalidation = false
        private var lastAppliedInsets = UIEdgeInsets.zero
        private var composerKeyboardConstraint: NSLayoutConstraint?
        private var composerSafeAreaConstraint: NSLayoutConstraint?
        private var isVisible = false

        init() {
            collectionView = UICollectionView(
                frame: .zero,
                collectionViewLayout: Self.makeLayout()
            )
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .clear
            if #available(iOS 26, *) {
                _ = view.keyboardLayoutGuide
            }

            configureCollectionView()
            configureHeaderHost()
            configureComposerView()
            configureDataSource()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            if updateComposerDockingIfNeeded() {
                view.setNeedsLayout()
                return
            }

            applyInsetsFromSiblingFrames(preservePosition: true)
        }

        override func viewSafeAreaInsetsDidChange() {
            super.viewSafeAreaInsetsDidChange()
            if updateComposerDockingIfNeeded() {
                view.setNeedsLayout()
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            isVisible = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            isVisible = false
            pendingObservedInvalidation = false
        }

        func update(model: ChatScreenModel, bindings: ChatScreenBindings, actions: ChatScreenActions) {
            updateHeader(model.header, bindings: bindings, actions: actions)
            updateComposer(model.composer, bindings: bindings, actions: actions.composer)
            updateMessages(model.messages, appearance: model.appearance, actions: actions.messages)
            view.setNeedsLayout()
        }

        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            // The hosting cells are self-sizing; subscriptions below keep visible rows current.
        }

        private func configureCollectionView() {
            collectionView.backgroundColor = .clear
            collectionView.alwaysBounceVertical = true
            collectionView.keyboardDismissMode = .interactive
            collectionView.contentInsetAdjustmentBehavior = .never
            collectionView.prefetchDataSource = self
            collectionView.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(collectionView)
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        private func configureHeaderHost() {
            addChild(headerHost)
            headerHost.view.backgroundColor = .clear
            headerHost.view.translatesAutoresizingMaskIntoConstraints = false
            headerHost.view.setContentHuggingPriority(.required, for: .vertical)
            headerHost.view.setContentCompressionResistancePriority(.required, for: .vertical)
            headerHost.sizingOptions = [.intrinsicContentSize]
            view.addSubview(headerHost.view)
            headerHost.didMove(toParent: self)

            NSLayoutConstraint.activate([
                headerHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                headerHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                headerHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }

        private func configureComposerView() {
            composerView.translatesAutoresizingMaskIntoConstraints = false
            composerView.setContentHuggingPriority(.required, for: .vertical)
            composerView.setContentCompressionResistancePriority(.required, for: .vertical)
            view.addSubview(composerView)

            let keyboardConstraint = composerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
            let safeAreaConstraint = composerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            composerKeyboardConstraint = keyboardConstraint
            composerSafeAreaConstraint = safeAreaConstraint

            NSLayoutConstraint.activate([
                composerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                composerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                safeAreaConstraint
            ])

            composerView.onHeightChange = { [weak self] in
                guard let self else { return }
                self.view.setNeedsLayout()
                UIView.performWithoutAnimation {
                    self.view.layoutIfNeeded()
                    self.applyInsetsFromSiblingFrames(preservePosition: true)
                }
            }
        }

        private static func makeLayout() -> UICollectionViewLayout {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(80)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: itemSize,
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

            let configuration = UICollectionViewCompositionalLayoutConfiguration()
            configuration.scrollDirection = .vertical
            return UICollectionViewCompositionalLayout(section: section, configuration: configuration)
        }

        private func configureDataSource() {
            let registration = UICollectionView.CellRegistration<UICollectionViewCell, UUID> { [weak self] cell, _, id in
                guard let self, let message = self.messagesByID[id] else {
                    cell.contentConfiguration = nil
                    return
                }

                let appearance = self.chatAppearance
                cell.backgroundColor = .clear
                cell.backgroundConfiguration = .clear()
                cell.contentConfiguration = UIHostingConfiguration {
                    MessageRow(
                        msg: message,
                        regenerate: { [weak self] message in
                            self?.messageActions?.regenerate(message)
                        },
                        switchVariant: { [weak self] id, direction in
                            self?.messageActions?.switchVariant(id, direction)
                        },
                        onDelete: { [weak self] id in
                            self?.messageActions?.delete(id)
                        }
                    )
                    .environment(\.chatAppearance, appearance)
                }
                .margins(.all, 0)
            }

            dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, id in
                collectionView.dequeueConfiguredReusableCell(
                    using: registration,
                    for: indexPath,
                    item: id
                )
            }
        }

        private func updateHeader(
            _ header: ChatScreenModel.Header,
            bindings: ChatScreenBindings,
            actions: ChatScreenActions
        ) {
            headerHost.rootView = AnyView(
                ChatTopPanel(
                    model: header,
                    bindings: bindings,
                    actions: actions
                )
                .environmentObject(header.apiManager)
            )
        }

        private func updateComposer(
            _ composer: ChatScreenModel.Composer,
            bindings: ChatScreenBindings,
            actions: ChatScreenActions.Composer
        ) {
            composerView.onTextChange = { text in
                guard bindings.inputText.wrappedValue != text else { return }
                bindings.inputText.wrappedValue = text
            }
            composerView.onSend = actions.send
            composerView.onStop = actions.stop
            composerView.configure(model: composer, text: bindings.inputText.wrappedValue)
        }

        private func updateMessages(
            _ messages: [ChatMessageModel],
            appearance: ChatAppearanceSnapshot,
            actions: ChatScreenActions.Messages
        ) {
            let previousAppearance = chatAppearance
            let nextMessageIDs = messages.map(\.id)
            let needsSnapshotUpdate = nextMessageIDs != appliedMessageIDs
            let needsAppearanceRefresh = previousAppearance != appearance

            self.messages = messages
            messagesByID = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
            chatAppearance = appearance
            messageActions = actions
            subscribeToMessageChanges(messages)

            if needsSnapshotUpdate || needsAppearanceRefresh {
                applySnapshotPreservingPosition(reconfigureExistingItems: needsAppearanceRefresh)
            }
        }

        private func updateComposerDockingIfNeeded() -> Bool {
            guard
                let composerKeyboardConstraint,
                let composerSafeAreaConstraint
            else { return false }

            let keyboardGuideFrame = view.keyboardLayoutGuide.layoutFrame
            let keyboardInset = max(0, view.bounds.maxY - keyboardGuideFrame.minY)
            let isKeyboardVisible = keyboardInset > view.safeAreaInsets.bottom + 1
            guard composerKeyboardConstraint.isActive != isKeyboardVisible else { return false }

            if isKeyboardVisible {
                composerSafeAreaConstraint.isActive = false
                composerKeyboardConstraint.isActive = true
            } else {
                composerKeyboardConstraint.isActive = false
                composerSafeAreaConstraint.isActive = true
            }

            return true
        }

        private func applyInsetsFromSiblingFrames(preservePosition: Bool) {
            guard collectionView.bounds.width > 0, collectionView.bounds.height > 0 else { return }

            let headerBottom = headerHost.view.frame.maxY
            let composerTop = composerView.frame.minY
            let topInset = max(0, headerBottom - collectionView.frame.minY)
            let bottomInset = max(0, collectionView.frame.maxY - composerTop)
            let nextInsets = UIEdgeInsets(
                top: ceil(topInset),
                left: 0,
                bottom: ceil(bottomInset),
                right: 0
            )

            guard !lastAppliedInsets.isApproximatelyEqual(to: nextInsets) else { return }

            let wasNearBottom = preservePosition && isNearBottom()
            let visibleAnchor = wasNearBottom ? nil : topVisibleAnchor()
            lastAppliedInsets = nextInsets
            collectionView.contentInset = nextInsets
            collectionView.scrollIndicatorInsets = nextInsets

            if wasNearBottom {
                scrollToBottom(animated: false)
            } else if let visibleAnchor {
                _ = restoreTopVisibleAnchor(visibleAnchor)
            }
        }

        private func applySnapshotPreservingPosition(reconfigureExistingItems: Bool) {
            guard let dataSource else { return }

            let messageIDs = messages.map(\.id)
            let oldContentHeight = collectionView.contentSize.height
            let oldOffset = collectionView.contentOffset
            let visibleAnchor = topVisibleAnchor()
            let wasNearBottom = isNearBottom() || oldContentHeight <= 0
            let existingIDs = Set(dataSource.snapshot().itemIdentifiers)

            var snapshot = Snapshot()
            snapshot.appendSections([.main])
            snapshot.appendItems(messageIDs, toSection: .main)
            if reconfigureExistingItems {
                snapshot.reconfigureItems(messageIDs.filter { existingIDs.contains($0) })
            }

            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                guard let self else { return }

                self.appliedMessageIDs = messageIDs
                self.collectionView.layoutIfNeeded()
                self.applyInsetsFromSiblingFrames(preservePosition: false)
                if wasNearBottom {
                    self.scrollToBottom(animated: false)
                    return
                }

                if let visibleAnchor, self.restoreTopVisibleAnchor(visibleAnchor) {
                    return
                }

                let heightDelta = self.collectionView.contentSize.height - oldContentHeight
                guard abs(heightDelta) > 0.5 else { return }
                self.collectionView.contentOffset = CGPoint(
                    x: oldOffset.x,
                    y: oldOffset.y + heightDelta
                )
            }
        }

        private func topVisibleAnchor() -> (id: UUID, offset: CGFloat)? {
            let visibleTopY = collectionView.contentOffset.y + collectionView.contentInset.top
            let sortedIndexPaths = collectionView.indexPathsForVisibleItems.sorted()

            for indexPath in sortedIndexPaths {
                guard
                    let id = dataSource?.itemIdentifier(for: indexPath),
                    let attributes = collectionView.layoutAttributesForItem(at: indexPath),
                    attributes.frame.maxY >= visibleTopY
                else {
                    continue
                }

                return (id, collectionView.contentOffset.y - attributes.frame.minY)
            }

            return nil
        }

        private func restoreTopVisibleAnchor(_ anchor: (id: UUID, offset: CGFloat)) -> Bool {
            guard
                let indexPath = dataSource?.indexPath(for: anchor.id),
                let attributes = collectionView.layoutAttributesForItem(at: indexPath)
            else {
                return false
            }

            let minY = -collectionView.contentInset.top
            let maxY = max(
                minY,
                collectionView.contentSize.height
                    + collectionView.contentInset.bottom
                    - collectionView.bounds.height
            )
            let targetY = min(max(attributes.frame.minY + anchor.offset, minY), maxY)
            collectionView.contentOffset = CGPoint(x: collectionView.contentOffset.x, y: targetY)
            return true
        }

        private func subscribeToMessageChanges(_ messages: [ChatMessageModel]) {
            let currentIDs = Set(messages.map(\.id))
            for id in messageCancellables.keys where !currentIDs.contains(id) {
                messageCancellables[id] = nil
            }

            for message in messages where messageCancellables[message.id] == nil {
                messageCancellables[message.id] = message.objectWillChange
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self, weak message] _ in
                        guard let self, let message else { return }
                        DispatchQueue.main.async {
                            self.scheduleObservedMessageInvalidation(for: message.id)
                        }
                    }
            }
        }

        private func scheduleObservedMessageInvalidation(for id: UUID) {
            guard messagesByID[id] != nil else { return }
            guard !pendingObservedInvalidation else { return }

            pendingObservedInvalidation = true
            let shouldFollowBottom = isNearBottom(threshold: 120) || messages.last?.id == id
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingObservedInvalidation = false
                guard self.isVisible, self.view.window != nil else { return }

                UIView.performWithoutAnimation {
                    self.collectionView.collectionViewLayout.invalidateLayout()
                    self.collectionView.performBatchUpdates(nil) { _ in
                        self.applyInsetsFromSiblingFrames(preservePosition: false)
                        if shouldFollowBottom {
                            self.scrollToBottom(animated: false)
                        }
                    }
                }
            }
        }

        private func isNearBottom(threshold: CGFloat = 48) -> Bool {
            let visibleMaxY = collectionView.contentOffset.y + collectionView.bounds.height
            let contentMaxY = collectionView.contentSize.height + collectionView.contentInset.bottom
            return contentMaxY - visibleMaxY <= threshold
        }

        private func scrollToBottom(animated: Bool) {
            collectionView.layoutIfNeeded()

            let minY = -collectionView.contentInset.top
            let maxY = collectionView.contentSize.height
                + collectionView.contentInset.bottom
                - collectionView.bounds.height
            let targetY = max(minY, maxY)
            collectionView.setContentOffset(
                CGPoint(x: collectionView.contentOffset.x, y: targetY),
                animated: animated
            )
        }
    }
}

private struct ChatTopPanel: View {
    let model: ChatScreenModel.Header
    let bindings: ChatScreenBindings
    let actions: ChatScreenActions

    var body: some View {
        HStack(spacing: 12) {
            Button(action: actions.navigation.dismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            ChatHeaderBar(
                bot: model.bot,
                botID: model.botID,
                chatAppearanceID: model.chatAppearanceID,
                currentChatTokenCount: model.currentChatTokenCount,
                tokenWindow: model.tokenWindow,
                personas: model.personas,
                currentPersona: model.currentPersona,
                globalPersona: model.globalPersona,
                hasPersonaOverride: model.hasPersonaOverride,
                showChatBotSheet: bindings.showChatBotSheet,
                isViewingHistory: bindings.isViewingHistory,
                onNewChat: actions.header.startNewChat,
                onSelectPersona: actions.header.selectPersona,
                onUseGlobalPersona: actions.header.useGlobalPersona
            )
            .frame(maxWidth: 320)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 44, height: 44)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

private final class ChatComposerView: UIView, UITextViewDelegate {
    var onTextChange: ((String) -> Void)?
    var onSend: (() -> Void)?
    var onStop: (() -> Void)?
    var onHeightChange: (() -> Void)?

    private enum Metrics {
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 8
        static let fieldHorizontalInset: CGFloat = 14
        static let fieldVerticalPadding: CGFloat = 6
        static let minimumFieldHeight: CGFloat = 52
        static let sendButtonSize: CGFloat = 40
        static var sendButtonEdgeInset: CGFloat {
            (minimumFieldHeight - sendButtonSize) / 2
        }
        static let maxLineCount = 10
    }

    private let fieldBackgroundView = UIVisualEffectView(effect: ChatComposerView.makeFieldGlassEffect())
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIControl()
    private let sendButtonGlassView = UIVisualEffectView(effect: ChatComposerView.makeSendButtonGlassEffect())
    private let sendButtonImageView = UIImageView()

    private var textViewHeightConstraint: NSLayoutConstraint?
    private var sendButtonWidthConstraint: NSLayoutConstraint?
    private var measuredTextViewHeight: CGFloat = 0
    private var isGenerating = false
    private var isThinking = false
    private var sendButtonStyle = ChatInputBarSendButtonStyle.defaultValue

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let fieldHeight = max(
            Metrics.minimumFieldHeight,
            measuredTextViewHeight + Metrics.fieldVerticalPadding * 2
        )
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: fieldHeight + Metrics.verticalInset * 2
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTextViewHeight(notify: false)
    }

    func configure(model: ChatScreenModel.Composer, text: String) {
        isGenerating = model.isGenerating
        isThinking = model.isThinking
        sendButtonStyle = model.sendButtonStyle
        placeholderLabel.text = model.placeholder

        if textView.text != text {
            textView.text = text
            updatePlaceholderVisibility()
            updateTextViewHeight(notify: true)
        }

        updateSendButton()
    }

    func setNeedsTextLayoutUpdate() {
        updateTextViewHeight(notify: true)
    }

    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        updateTextViewHeight(notify: true)
        updateSendButton()
        onTextChange?(textView.text)
    }

    private func setup() {
        backgroundColor = .clear

        fieldBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        fieldBackgroundView.clipsToBounds = true
        fieldBackgroundView.layer.cornerRadius = Metrics.minimumFieldHeight / 2
        fieldBackgroundView.layer.cornerCurve = .continuous
        addSubview(fieldBackgroundView)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = false

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 1

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.layer.cornerRadius = Metrics.sendButtonSize / 2
        sendButton.layer.cornerCurve = .continuous
        sendButton.clipsToBounds = true
        sendButton.addTarget(self, action: #selector(primaryButtonTapped), for: .touchUpInside)
        sendButton.accessibilityTraits = [.button]

        sendButtonGlassView.translatesAutoresizingMaskIntoConstraints = false
        sendButtonGlassView.isUserInteractionEnabled = false
        sendButtonGlassView.clipsToBounds = true
        sendButtonGlassView.layer.cornerRadius = Metrics.sendButtonSize / 2
        sendButtonGlassView.layer.cornerCurve = .continuous

        sendButtonImageView.translatesAutoresizingMaskIntoConstraints = false
        sendButtonImageView.isUserInteractionEnabled = false
        sendButtonImageView.contentMode = .center
        sendButtonImageView.tintColor = .black

        sendButton.addSubview(sendButtonGlassView)
        sendButton.addSubview(sendButtonImageView)

        let contentView = fieldBackgroundView.contentView
        contentView.addSubview(textView)
        contentView.addSubview(placeholderLabel)
        contentView.addSubview(sendButton)

        let textHeight = initialTextViewHeight()
        measuredTextViewHeight = textHeight
        let textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: textHeight)
        let sendButtonWidthConstraint = sendButton.widthAnchor.constraint(equalToConstant: Metrics.sendButtonSize)
        self.textViewHeightConstraint = textViewHeightConstraint
        self.sendButtonWidthConstraint = sendButtonWidthConstraint

        NSLayoutConstraint.activate([
            fieldBackgroundView.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.verticalInset),
            fieldBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.horizontalInset),
            fieldBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.horizontalInset),
            fieldBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Metrics.verticalInset),
            fieldBackgroundView.heightAnchor.constraint(greaterThanOrEqualToConstant: Metrics.minimumFieldHeight),

            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metrics.fieldHorizontalInset),
            textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            textView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: Metrics.fieldVerticalPadding),
            textView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Metrics.fieldVerticalPadding),
            textViewHeightConstraint,

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: textView.textContainerInset.top),

            sendButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Metrics.sendButtonEdgeInset),
            sendButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            sendButtonWidthConstraint,
            sendButton.heightAnchor.constraint(equalToConstant: Metrics.sendButtonSize),

            sendButtonGlassView.topAnchor.constraint(equalTo: sendButton.topAnchor),
            sendButtonGlassView.leadingAnchor.constraint(equalTo: sendButton.leadingAnchor),
            sendButtonGlassView.trailingAnchor.constraint(equalTo: sendButton.trailingAnchor),
            sendButtonGlassView.bottomAnchor.constraint(equalTo: sendButton.bottomAnchor),

            sendButtonImageView.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            sendButtonImageView.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
            sendButtonImageView.widthAnchor.constraint(equalToConstant: 32),
            sendButtonImageView.heightAnchor.constraint(equalToConstant: 32)
        ])

        updatePlaceholderVisibility()
        updateSendButton()
    }

    private func updateTextViewHeight(notify: Bool) {
        guard textView.bounds.width > 0 else { return }

        let fittingSize = CGSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        let measuredHeight = textView.sizeThatFits(fittingSize).height
        let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
        let insetHeight = textView.textContainerInset.top + textView.textContainerInset.bottom
        let minHeight = ceil(font.lineHeight + insetHeight)
        let maxHeight = ceil(font.lineHeight * CGFloat(Metrics.maxLineCount) + insetHeight)
        let nextHeight = min(max(ceil(measuredHeight), minHeight), maxHeight)

        guard abs(measuredTextViewHeight - nextHeight) > 0.5 else {
            textView.isScrollEnabled = measuredHeight > maxHeight + 0.5
            return
        }

        measuredTextViewHeight = nextHeight
        textViewHeightConstraint?.constant = nextHeight
        textView.isScrollEnabled = measuredHeight > maxHeight + 0.5
        invalidateIntrinsicContentSize()

        if notify {
            onHeightChange?()
        }
    }

    private func initialTextViewHeight() -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        return ceil(font.lineHeight + textView.textContainerInset.top + textView.textContainerInset.bottom)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    private func updateSendButton() {
        let symbolName: String
        if isGenerating {
            symbolName = isThinking ? "circle.hexagongrid" : "stop.fill"
        } else {
            symbolName = "arrow.up"
        }

        let imageConfiguration = UIImage.SymbolConfiguration(pointSize: 27, weight: .semibold)
        sendButtonImageView.image = UIImage(systemName: symbolName, withConfiguration: imageConfiguration)
        sendButton.accessibilityLabel = isGenerating ? "Stop" : "Send"
        sendButtonWidthConstraint?.constant = max(Metrics.sendButtonSize, sendButtonStyle.iconFrameWidth)

        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = isGenerating || hasText
        sendButton.alpha = sendButton.isEnabled ? 1 : 0.55
    }

    @objc private func primaryButtonTapped() {
        if isGenerating {
            onStop?()
            return
        }

        guard !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend?()
    }

    private static func makeFieldGlassEffect() -> UIGlassEffect {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        return effect
    }

    private static func makeSendButtonGlassEffect() -> UIGlassEffect {
        let effect = UIGlassEffect(style: .regular)
        effect.tintColor = UIColor.white.withAlphaComponent(1)
        effect.isInteractive = true
        return effect
    }
}

private extension UIEdgeInsets {
    func isApproximatelyEqual(to other: UIEdgeInsets) -> Bool {
        abs(top - other.top) <= 0.5 &&
            abs(left - other.left) <= 0.5 &&
            abs(bottom - other.bottom) <= 0.5 &&
            abs(right - other.right) <= 0.5
    }
}
