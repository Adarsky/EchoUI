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
    func scheduleDraftPersistence(_ draft: String) {
        guard !isPreviewSeeded else { return }
        draftSaveTask?.cancel()

        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clearSavedDraft()
            return
        }

        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            _ = ChatDraftStore.saveDraft(draft, for: botID)
            draftSaveTask = nil
        }
    }

    @MainActor
    func persistDraftImmediately() {
        guard !isPreviewSeeded else { return }
        draftSaveTask?.cancel()
        draftSaveTask = nil
        _ = ChatDraftStore.saveDraft(inputText, for: botID)
    }

    @MainActor
    func clearSavedDraft() {
        guard !isPreviewSeeded else { return }
        draftSaveTask?.cancel()
        draftSaveTask = nil
        _ = ChatDraftStore.removeDraft(for: botID)
    }
}
