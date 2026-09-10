import PhotosUI
import SwiftUI

struct CharacterAvatarPicker: View {
    @Binding var selection: PhotosPickerItem?
    let avatarData: Data?
    let avatarSystemName: String
    let requiresPhoto: Bool
    let isLoading: Bool

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: 12) {
                Group {
                    if let avatarData, let image = UIImage(data: avatarData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: avatarSystemName)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .padding(24)
                    }
                }
                .frame(width: 122, height: 122)
                .background(.quaternary, in: .circle)
                .clipShape(.circle)
                .accessibilityHidden(true)
                .overlay {
                    if isLoading {
                        ProgressView()
                            .padding()
                            .background(.regularMaterial, in: .circle)
                    }
                }

                Text(avatarData == nil ? "Add Photo" : "Change Photo")
                    .font(.body)
                    .foregroundStyle(.tint)

                if requiresPhoto && avatarData == nil {
                    Text("Required for new characters")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(avatarData == nil ? "Add character photo" : "Change character photo")
    }
}
