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

    @State private var selectedImage: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $bot.name)
            }

            Section("Subtitle (System Prompt)") {
                TextField("Subtitle", text: $bot.subtitle, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Greeting") {
                TextField("Greeting", text: $bot.greeting)
            }

            Section("Icon & Color") {
                ColorPicker("Color", selection: Binding(
                    get: { Color(bot.iconColorName) },
                    set: { bot.iconColorName = $0.description }
                ))

                TextField("System Icon", text: $bot.avatarSystemName)
            }

            Section("Avatar") {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Text("Choose Photo")
                }
                .onChange(of: selectedImage) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            bot.avatarData = data
                        }
                    }
                }

                if let data = bot.avatarData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .padding(.top, 10)
                } else {
                    Image(systemName: bot.avatarSystemName)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(bot.iconColorName))
                        .clipShape(Circle())
                        .padding(.top, 10)
                }
            }
        }
        .navigationTitle("Edit Bot")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}
