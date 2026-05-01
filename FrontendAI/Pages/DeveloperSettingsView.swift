//
//  DeveloperSettingsView.swift
//  FrontendAI
//
//  Created by Codex on 30.04.2026.
//

import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage(OpenRouterAttributionStorageKeys.httpReferer) private var openRouterHTTPReferer = OpenRouterAttributionHeaders.defaultReferer
    @AppStorage(OpenRouterAttributionStorageKeys.xTitle) private var openRouterXTitle = OpenRouterAttributionHeaders.defaultTitle
    @AppStorage(OpenRouterAttributionStorageKeys.userAgent) private var openRouterUserAgent = OpenRouterAttributionHeaders.defaultUserAgent

    var body: some View {
        List {
            Section(header: Text("OpenRouter identity"), footer: Text("Not recommended to these change settings if you don't know what they are")) {
                TextField("HTTP-Referer", text: $openRouterHTTPReferer)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField("X-Title", text: $openRouterXTitle)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField("User-Agent", text: $openRouterUserAgent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Presets") {
                ForEach(OpenRouterAttributionHeaders.presets) { preset in
                    Button {
                        apply(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                Text(preset.httpReferer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected(preset) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func apply(_ preset: OpenRouterAttributionPreset) {
        openRouterHTTPReferer = preset.httpReferer
        openRouterXTitle = preset.xTitle
        openRouterUserAgent = preset.userAgent
    }

    private func isSelected(_ preset: OpenRouterAttributionPreset) -> Bool {
        OpenRouterAttributionHeaders.matchingPreset(
            httpReferer: openRouterHTTPReferer,
            xTitle: openRouterXTitle,
            userAgent: openRouterUserAgent
        ) == preset
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
