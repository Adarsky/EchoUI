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
    @State private var navigateToAPIManager = false
    @AppStorage("showAvatars") private var showAvatars: Bool = true


    var body: some View {
        let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimum = 1
            formatter.maximum = 8192
            return formatter
        }()
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Text("Settings")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Button("Close") {
                        isPresented = false
                    }
                }
                
                List {
                    Section(header: Text("CONNECTION CONFIGURATION")) {
                        NavigationLink(destination: APIManagerView(selectedServer: .constant(nil))) {
                            HStack {
                                Image(systemName: "server.rack")
                                Text("Manage API Servers")
                            }
                        }
                    }

                    Section(header: Text("CHAT CONFIGURATION")) {
                        Toggle("Show avatars", isOn: $showAvatars)

                        HStack {
                            Text("Max Length")
                            Spacer()
                            Stepper("\(messageLength)", value: $messageLength, in: 1...8192)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                Spacer()
            }
            .padding()
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}



#Preview {
    SettingsSheetView(
        isPresented: .constant(true),
        messageLength: .constant(2048),
        endpoint: .constant("http://localhost:5000")
    )
}
