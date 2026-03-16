//
//  EditBotView.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//


import SwiftUI
import SwiftData
import PhotosUI

struct EditBotView: View {
    @Bindable var bot: BotModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var selectedImageItem: PhotosPickerItem? = nil
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case greeting
        case description
    }

    private var canSave: Bool {
        !bot.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bot.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    bot.avatarData = data
                }
            }
        }
        .onChange(of: bot.name) { _, newValue in
            bot.name = BotModel.clampedName(newValue)
        }
        .onChange(of: bot.subtitle) { _, newValue in
            bot.subtitle = BotModel.clampedSubtitle(newValue)
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

            TextField("e.g. Luna", text: $bot.name)
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
            text: $bot.greeting,
            field: .greeting,
            nextField: .description
        )
    }

    private var descriptionCard: some View {
        textEditorCard(
            title: "Description",
            icon: "text.alignleft",
            placeholder: "Describe personality, style and behavior...",
            text: $bot.subtitle,
            field: .description,
            nextField: nil
        )
    }

    private func textEditorCard(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        nextField: Field?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .padding(.leading, 12)
                }

                TextEditor(text: text)
                    .focused($focusedField, equals: field)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .submitLabel(nextField == nil ? .done : .next)
                    .onSubmit {
                        focusedField = nextField
                    }
            }
            .background(inputBackground)
        }
        .padding(16)
        .background(cardBackground)
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
            if let data = bot.avatarData, let image = UIImage(data: data) {
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
        bot.name = BotModel.clampedName(bot.name.trimmingCharacters(in: .whitespacesAndNewlines))
        bot.subtitle = BotModel.clampedSubtitle(bot.subtitle.trimmingCharacters(in: .whitespacesAndNewlines))
        bot.greeting = bot.greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}
