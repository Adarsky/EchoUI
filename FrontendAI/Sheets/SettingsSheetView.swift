//
//  SettingsSheetView.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//

import SwiftUI

struct SettingsSheetView: View {
    @Binding var isPresented: Bool
    @Binding var messageLength: Int
    @Binding var endpoint: String
    var navName: String = "Settings"

    @Namespace private var settingsNavNamespace

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                List {
                    Section(header: Text("CUSTOMIZATION")) {
                        NavigationLink(destination: ChatAppearanceSettingsView()) {
                            HStack {
                                Image(systemName: "paintpalette")
                                Text("Chat Appearance")
                            }
                        }
                    }

                    Section(header: Text("CONNECTION CONFIGURATION")) {
                        NavigationLink(destination: APIManagerView(selectedServer: .constant(nil))) {
                            HStack {
                                Image(systemName: "server.rack")
                                Text("Manage API Servers")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                Spacer()
            }
            .navigationTitle(navName)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct SettingsSheetViewPreviewHost: View {
    @State private var isPresented = true
    @State private var messageLength = 1024
    @State private var endpoint = "http://localhost:1234/v1"
    var navName: String = "Settings"

    var body: some View {
        SettingsSheetView(
            isPresented: $isPresented,
            messageLength: $messageLength,
            endpoint: $endpoint,
            navName: navName
        )
    }
}

#Preview {
    SettingsSheetViewPreviewHost()
}

#Preview("Custom Nav Name") {
    SettingsSheetViewPreviewHost(navName: "App Settings")
        .environment(\.locale, .init(identifier: "en"))
}
