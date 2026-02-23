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

    @Namespace private var settingsNavNamespace

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                GlassEffectContainer {
                    HStack {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "chevron.left")
                                .imageScale(.large)
                        }
                        .buttonStyle(.glass)
                        .glassEffectUnion(id: 1, namespace: settingsNavNamespace)

                        Spacer()

                        Text("Settings")
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular)
                            .glassEffectUnion(id: 2, namespace: settingsNavNamespace)

                        Spacer()

                        Color.clear
                            .frame(width: 34, height: 34)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
