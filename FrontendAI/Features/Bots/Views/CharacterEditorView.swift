import PhotosUI
import SwiftData
import SwiftUI

struct CharacterEditorView: View {
    let bot: BotModel?
    let onCreate: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: CharacterDraft
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingAvatarImage: AvatarEditorDraftImage?
    @State private var isLoadingPhoto = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showsError = false
    @FocusState private var focusedField: CharacterEditorField?

    init(bot: BotModel? = nil, onCreate: (() -> Void)? = nil) {
        self.bot = bot
        self.onCreate = onCreate
        _draft = State(initialValue: CharacterDraft(bot: bot))
    }

    private var validationMessage: String? {
        draft.validationMessage(requiresPhoto: bot == nil)
    }

    private var hasChanges: Bool {
        bot.map { draft.hasChanges(from: $0) } ?? true
    }

    private var canSave: Bool {
        validationMessage == nil && hasChanges && !isLoadingPhoto && selectedPhoto == nil
    }

    var body: some View {
        Form {
            Section {
                CharacterAvatarPicker(
                    selection: $selectedPhoto,
                    avatarData: draft.avatarData,
                    avatarSystemName: bot?.avatarSystemName ?? "person.crop.circle.fill",
                    requiresPhoto: bot == nil,
                    isLoading: isLoadingPhoto
                )
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("e.g. Luna", text: $draft.name)
                    .accessibilityLabel("Name")
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .textInputAutocapitalization(.words)
                    .onSubmit { focusedField = .greeting }
            } header: {
                Text("Name")
            } footer: {
                Text("Required. Up to \(BotModel.maxNameLength) characters.")
            }

            CharacterTextEditorSection(
                title: "Greeting",
                placeholder: "How does the character start a chat?",
                footer: "Optional. The first message in a new chat.",
                text: $draft.greeting,
                focusedField: $focusedField,
                field: .greeting
            )

            CharacterTextEditorSection(
                title: "Description",
                placeholder: "Describe personality, style and behavior…",
                footer: validationMessage ?? (hasChanges ? "Required. Defines how your character responds." : "No changes to save."),
                text: $draft.description,
                focusedField: $focusedField,
                field: .description
            )
        }
        .navigationTitle(bot == nil ? "New Character" : "Edit Character")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(bot == nil ? "Create" : "Save", role: .confirm, action: save)
                    .disabled(!canSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityHint(validationMessage ?? (hasChanges ? "Saves this character." : "No changes to save."))
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: dismissKeyboard)
            }
        }
        .onChange(of: draft.name) { _, newValue in
            let clampedName = BotModel.clampedName(newValue)
            if clampedName != newValue {
                draft.name = clampedName
            }
        }
        .task(id: selectedPhoto) {
            await loadPhoto()
        }
        .sheet(item: $pendingAvatarImage, onDismiss: cancelPhotoEditing) { image in
            AvatarImageEditorView(
                image: image.image,
                onCancel: cancelPhotoEditing,
                onApply: applyPhoto
            )
        }
        .alert(errorTitle, isPresented: $showsError) { } message: {
            Text(errorMessage)
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func loadPhoto() async {
        guard let selectedPhoto else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            let data = try await selectedPhoto.loadTransferable(type: Data.self)
            try Task.checkCancellation()
            guard let data, let image = UIImage(data: data) else {
                showError(title: "Couldn’t Load Photo", message: "Choose another photo and try again.")
                self.selectedPhoto = nil
                return
            }
            focusedField = nil
            pendingAvatarImage = AvatarEditorDraftImage(image: image)
        } catch {
            guard !Task.isCancelled else { return }
            showError(title: "Couldn’t Load Photo", message: "Choose another photo and try again.")
            self.selectedPhoto = nil
        }
    }

    private func cancelPhotoEditing() {
        pendingAvatarImage = nil
        selectedPhoto = nil
    }

    private func applyPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            cancelPhotoEditing()
            showError(title: "Couldn’t Use Photo", message: "Choose another photo and try again.")
            return
        }
        draft.avatarData = data
        cancelPhotoEditing()
    }

    private func save() {
        guard canSave else { return }
        focusedField = nil
        do {
            try draft.save(in: modelContext, editing: bot)
            dismiss()
            if bot == nil {
                onCreate?()
            }
        } catch {
            showError(
                title: "Couldn’t Save Character",
                message: "Your changes are still here. Please try saving again.\n\n\(error.localizedDescription)"
            )
        }
    }

    private func showError(title: String, message: String) {
        errorTitle = title
        errorMessage = message
        showsError = true
    }
}
