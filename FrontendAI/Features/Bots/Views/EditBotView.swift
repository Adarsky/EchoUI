import SwiftUI
import SwiftData
import PhotosUI

struct EditBotView: View {
    let bot: BotModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var draftName: String
    @State private var draftGreeting: String
    @State private var draftSubtitle: String
    @State private var draftAvatarData: Data?
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var pendingAvatarImage: AvatarEditorDraftImage? = nil
    @State private var isGreetingEditorExpanded = false
    @State private var isDescriptionEditorExpanded = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case greeting
        case description
    }

    init(bot: BotModel) {
        self.bot = bot
        _draftName = State(initialValue: bot.name)
        _draftGreeting = State(initialValue: bot.greeting)
        _draftSubtitle = State(initialValue: bot.subtitle)
        _draftAvatarData = State(initialValue: bot.avatarData)
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                nameCard
                greetingCard
                descriptionCard
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Edit Character")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedImageItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        pendingAvatarImage = AvatarEditorDraftImage(image: image)
                    }
                }
            }
        }
        .onChange(of: draftName) { _, newValue in
            let clampedName = BotModel.clampedName(newValue)
            if clampedName != newValue {
                draftName = clampedName
            }
        }
        .onChange(of: draftSubtitle) { _, newValue in
            let clampedSubtitle = BotModel.clampedSubtitle(newValue)
            if clampedSubtitle != newValue {
                draftSubtitle = clampedSubtitle
            }
        }
        .sheet(item: $pendingAvatarImage) { draft in
            AvatarImageEditorView(
                image: draft.image,
                onCancel: {
                    pendingAvatarImage = nil
                    selectedImageItem = nil
                },
                onApply: { editedImage in
                    draftAvatarData = editedImage.jpegData(compressionQuality: 0.9)
                    pendingAvatarImage = nil
                    selectedImageItem = nil
                }
            )
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 14) {
                    avatarPreview

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Character avatar")
                            .font(.headline)
                        Text("Choose a photo to update the character image")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(cardBackground)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Name", systemImage: "person.text.rectangle")
                .font(.subheadline.weight(.semibold))

            TextField("e.g. Luna", text: $draftName)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(inputBackground)
                .onSubmit {
                    focusedField = .greeting
                }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var greetingCard: some View {
        textEditorCard(
            title: "Greeting",
            icon: "quote.bubble",
            placeholder: "How does the character start a chat?",
            text: $draftGreeting,
            field: .greeting,
            nextField: .description,
            isExpanded: $isGreetingEditorExpanded
        )
    }

    private var descriptionCard: some View {
        textEditorCard(
            title: "Description",
            icon: "text.alignleft",
            placeholder: "Describe personality, style and behavior...",
            text: $draftSubtitle,
            field: .description,
            nextField: nil,
            isExpanded: $isDescriptionEditorExpanded
        )
    }

    private func textEditorCard(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        nextField: Field?,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    isExpanded.wrappedValue = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Expand \(title)")
            }

            TextEditor(text: text)
                .focused($focusedField, equals: field)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.never)
                .frame(maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.clear)
                .overlay(alignment: .topLeading) {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .padding(.leading, 12)
                        .opacity(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .frame(height: 142)
                .submitLabel(nextField == nil ? .done : .next)
                .onSubmit {
                    focusedField = nextField
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            .background(inputBackground)
        }
        .padding(16)
        .background(cardBackground)
        .sheet(isPresented: isExpanded) {
            ExpandedTextEditorSheet(
                text: text,
                title: title,
                placeholder: placeholder
            )
        }
    }

    private var saveButton: some View {
        Button(action: saveBot) {
            Text("Save Character")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .disabled(!canSave)
        .padding(.top, 4)
    }

    private var avatarPreview: some View {
        Group {
            if let data = draftAvatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: bot.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(bot.iconColorName))
                    .padding(16)
            }
        }
        .frame(width: 84, height: 84)
        .background(Circle().fill(.white.opacity(0.12)))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white.opacity(0.32), lineWidth: 1)
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 0)
            )
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0)
            )
    }

    private func saveBot() {
        bot.name = BotModel.clampedName(draftName.trimmingCharacters(in: .whitespacesAndNewlines))
        bot.subtitle = BotModel.clampedSubtitle(draftSubtitle.trimmingCharacters(in: .whitespacesAndNewlines))
        bot.greeting = draftGreeting.trimmingCharacters(in: .whitespacesAndNewlines)
        bot.avatarData = draftAvatarData
        try? modelContext.save()
        dismiss()
    }
}
