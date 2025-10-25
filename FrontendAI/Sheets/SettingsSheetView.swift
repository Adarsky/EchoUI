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

