import Foundation

extension ChatView {
    @MainActor
    func restoreDraftIfNeeded() {
        guard !hasRestoredDraft else { return }
        hasRestoredDraft = true
        guard !isPreviewSeeded,
              inputText.isEmpty,
              let draft = ChatDraftStore.loadDraft(for: botID) else {
            return
        }

        inputText = draft
    }

    @MainActor
    func persistDraftImmediately() {
        guard !isPreviewSeeded else { return }
        _ = ChatDraftStore.saveDraft(inputText, for: botID)
    }

    @MainActor
    func clearSavedDraft() {
        guard !isPreviewSeeded else { return }
        _ = ChatDraftStore.removeDraft(for: botID)
    }
}
