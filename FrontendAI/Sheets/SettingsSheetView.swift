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
    @Binding var showAPIStatus: Bool
    @AppStorage(ChatStreamingStorageKeys.chunkFlushIntervalMs) private var streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
    @State private var showChunkTimeInfo = false
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
                    
                    Section(header: Text("MAIN HUB")) {
                        Toggle("Show API Status", isOn: $showAPIStatus)
                    }

                    Section(header: Text("CONNECTION CONFIGURATION")) {
                        NavigationLink(destination: APIManagerView(selectedServer: .constant(nil))) {
                            HStack {
                                Image(systemName: "server.rack")
                                Text("Manage API Servers")
                            }
                        }
                        HStack {
                            Image(systemName: "hare")
                            Text("Chunk time: \(Int(streamChunkFlushIntervalMs.rounded())) ms")
                            Spacer()
                            Button {
                                showChunkTimeInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Chunk time info")
                        }
                        Slider(
                            value: $streamChunkFlushIntervalMs,
                            in: ChatStreamingDefaults.minChunkFlushIntervalMs...ChatStreamingDefaults.maxChunkFlushIntervalMs,
                            step: 10
                        )
                        Button("Reset chunk time default") {
                            streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .frame(maxWidth: 460, alignment: .leading)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .navigationTitle(navName)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear {
                streamChunkFlushIntervalMs = ChatStreamingDefaults.clampedChunkFlushIntervalMs(streamChunkFlushIntervalMs)
            }
            .alert("Chunk Time", isPresented: $showChunkTimeInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This controls how often streamed LLM text is flushed to the chat UI. Lower values update text more frequently with smaller chunks. Higher values batch more text per update, which can feel less live but may reduce UI update overhead.")
            }
        }
    }
}

private struct SettingsSheetViewPreviewHost: View {
    @State private var isPresented = true
    @State private var messageLength = 1024
    @State private var endpoint = "http://localhost:1234/v1"
    @State private var showAPIStatus = true
    var navName: String = "Settings"

    var body: some View {
        SettingsSheetView(
            isPresented: $isPresented,
            messageLength: $messageLength,
            endpoint: $endpoint,
            showAPIStatus: $showAPIStatus,
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
