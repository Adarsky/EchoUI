//
//  AppIconSettingsView.swift
//  FrontendAI
//

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
                            Label(icon.title, systemImage: icon.systemImage)
                            Spacer()
                            if selectedIconName == icon.alternateIconName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .disabled(isChangingIcon || selectedIconName == icon.alternateIconName)
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

private enum AppIconChoice: CaseIterable, Identifiable {
    case primary
    case appIcon1
    case appIcon2

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
        }
    }

    var systemImage: String {
        switch self {
        case .primary:
            return "app"
        case .appIcon1:
            return "app.fill"
        case .appIcon2:
            return "app.badge"
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
        }
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
}
