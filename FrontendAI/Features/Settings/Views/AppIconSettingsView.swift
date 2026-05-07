import SwiftUI
import UIKit

struct AppIconSettingsView: View {
    @State private var selectedIconName = UIApplication.shared.alternateIconName
    @State private var isChangingIcon = false
    @State private var iconChangeError: String?

    var body: some View {
        List {
            Section("Icon") {
                ForEach(AppIconChoice.allCases) { icon in
                    Button {
                        changeIcon(to: icon)
                    } label: {
                        HStack {
                            AppIconPreview(assetName: icon.previewAssetName)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(icon.title)
                                    .foregroundStyle(.primary)

                                Text(icon.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedIconName == icon.alternateIconName {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                                    .imageScale(.large)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(isChangingIcon)
                }
            }

            if !UIApplication.shared.supportsAlternateIcons {
                Section {
                    Label(
                        "Alternate icons work only when the app is installed on iOS. They are unavailable in previews and may be unavailable when running as an iPhone app on Mac.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedIconName = UIApplication.shared.alternateIconName
        }
        .alert("Could Not Change Icon", isPresented: hasIconChangeError) {
            Button("OK", role: .cancel) {
                iconChangeError = nil
            }
        } message: {
            Text(iconChangeError ?? "")
        }
    }

    private var hasIconChangeError: Binding<Bool> {
        Binding(
            get: { iconChangeError != nil },
            set: { isPresented in
                if !isPresented {
                    iconChangeError = nil
                }
            }
        )
    }

    private func changeIcon(to icon: AppIconChoice) {
        guard selectedIconName != icon.alternateIconName else {
            return
        }

        guard UIApplication.shared.supportsAlternateIcons else {
            iconChangeError = "Alternate app icons are not available on this device."
            return
        }

        isChangingIcon = true

        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            Task { @MainActor in
                isChangingIcon = false

                if let error {
                    iconChangeError = error.localizedDescription
                    selectedIconName = UIApplication.shared.alternateIconName
                    return
                }

                selectedIconName = icon.alternateIconName
            }
        }
    }
}

private struct AppIconPreview: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .accessibilityHidden(true)
    }
}

private enum AppIconChoice: CaseIterable, Identifiable {
    case primary
    case appIcon1
    case appIcon2
    case appIcon3
    case appIcon4

    var id: String {
        alternateIconName ?? "primary"
    }

    var title: String {
        switch self {
        case .primary:
            return "Default"
        case .appIcon1:
            return "AppIcon 1"
        case .appIcon2:
            return "AppIcon 2"
        case .appIcon3:
            return "AppIcon 3"
        case .appIcon4:
            return "AppIcon 4"
        }
    }

    var subtitle: String {
        switch self {
        case .primary:
            return "Current default icon"
        case .appIcon1:
            return "Alternate icon"
        case .appIcon2:
            return "Alternate icon"
        case .appIcon3:
            return "Alternate icon"
        case .appIcon4:
            return "Alternate icon"
        }
    }

    var previewAssetName: String {
        switch self {
        case .primary:
            return "AppIconPreview"
        case .appIcon1:
            return "AppIcon1Preview"
        case .appIcon2:
            return "AppIcon2Preview"
        case .appIcon3:
            return "AppIcon3Preview"
        case .appIcon4:
            return "AppIcon4Preview"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .primary:
            return nil
        case .appIcon1:
            return "AppIcon1"
        case .appIcon2:
            return "AppIcon2"
        case .appIcon3:
            return "AppIcon3"
        case .appIcon4:
            return "AppIcon4"
        }
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
}
