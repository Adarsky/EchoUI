//
//  CreatingBot.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//

import SwiftUI
import PhotosUI

struct CreateCharacterView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var avatarImage: UIImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var greeting: String = ""
    
    @State private var showMissingPhotoAlert = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case greeting
        case description
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                nameCard
                greetingCard
                descriptionCard
                createButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("New Character")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    avatarImage = uiImage
                }
            }
        }
        .onChange(of: name) { _, newValue in
            name = BotModel.clampedName(newValue)
        }
        .onChange(of: description) { _, newValue in
            description = BotModel.clampedSubtitle(newValue)
        }
        .alert("Photo was not selected, please select it", isPresented: $showMissingPhotoAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 14) {
                    avatarPreview

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Character avatar")
                            .font(.headline)
                        Text("A photo is required before saving")
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

            TextField("e.g. Luna", text: $name)
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
            text: $greeting,
            field: .greeting,
            nextField: .description
        )
    }

    private var descriptionCard: some View {
        textEditorCard(
            title: "Description",
            icon: "text.alignleft",
            placeholder: "Describe personality, style and behavior...",
            text: $description,
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

    private var createButton: some View {
        Button(action: saveCharacter) {
            Text("Create Character")
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
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.accentColor)
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

//    private var backgroundGradient: some View {
//        LinearGradient(
//            colors: [
//                Color.accentColor.opacity(0.16),
//                Color.blue.opacity(0.12),
//                Color.clear
//            ],
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        )
//    }

    private func saveCharacter() {
        guard let avatarImage,
              let imageData = avatarImage.jpegData(compressionQuality: 0.8)
        else {
            showMissingPhotoAlert = true
            return
        }

        let newBot = BotModel(
            name: BotModel.clampedName(name.trimmingCharacters(in: .whitespacesAndNewlines)),
            subtitle: BotModel.clampedSubtitle(description.trimmingCharacters(in: .whitespacesAndNewlines)),
            date: formattedToday(),
            avatarSystemName: "person.crop.circle.fill",
            iconColorName: "blue",
            isPinned: false,
            avatarData: imageData,
            greeting: greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(newBot)
        try? modelContext.save()
        dismiss()
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}

typealias CreateBotView = CreateCharacterView

#Preview {
    NavigationStack {
        CreateCharacterView()
    }
        .modelContainer(for: BotModel.self, inMemory: true)
}
