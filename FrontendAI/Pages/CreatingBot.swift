//
//  CreatingBot.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//

import SwiftUI
import PhotosUI

struct CreateBotView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var avatarImage: UIImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var greeting: String = ""
    
    @State private var showMissingPhotoAlert = false
    @Environment(PersonaManager.self) var personaManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Фото
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                        }
                    }
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            avatarImage = uiImage
                        }
                    }
                }

                // Имя
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                    HStack{
                        Text("Greeting")
                        Spacer()
                    }.padding(.leading, 16)
                
                TextEditor(text: $greeting)
                    .frame(height: 120)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                HStack{
                    Text("Description")
                    Spacer()
                }.padding(.leading, 16)
                
                // Описание
                TextEditor(text: $description)
                    .frame(height: 120)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                
                Spacer()

                // Сохранить
                Button("Safe") {
                    guard let avatarImage,
                          let imageData = avatarImage.jpegData(compressionQuality: 0.8)
                    else {
                        showMissingPhotoAlert = true
                        return
                    }

                    let newBot = BotModel(
                        name: name,
                        subtitle: description,
                        date: formattedToday(),
                        avatarSystemName: "person.crop.circle",
                        iconColorName: "blue",
                        isPinned: false,
                        avatarData: imageData,
                        greeting: greeting
                    )

                    modelContext.insert(newBot)
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(name.isEmpty || description.isEmpty)
                .buttonStyle(.borderedProminent)
                .padding()
                .alert("Photo was not selected, please select it", isPresented: $showMissingPhotoAlert) {
                    Button("OK", role: .cancel) { }
                }
            }
            .navigationTitle("Your new character")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}

struct CreateBotView_Previews: PreviewProvider {
    static var previews: some View {
        CreateBotView()
    }
}

        struct CreateBotView_Pre: PreviewProvider {
            static var previews: some View {
                CreateBotView()
            }
        }

