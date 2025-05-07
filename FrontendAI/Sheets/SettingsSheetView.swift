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
    
    @AppStorage("temperature") private var temperature: Double = 0.7
    @AppStorage("top_p") private var top_p: Double = 0.9
    @AppStorage("top_k") private var top_k: Double = 40
    @AppStorage("repeat_penalty") private var repeatPenalty: Double = 1.0
    @AppStorage("max_generated_tokens") private var maxTokens: Int = 1024

    
    
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
                    
                    Section(header: Text("GENERATION PARAMETERS")) {
                        Stepper(value: $temperature, in: 0.0...2.0, step: 0.05) {
                            Text("Temperature: \(temperature, specifier: "%.2f")")
                        }

                        Stepper(value: $top_p, in: 0.0...1.0, step: 0.05) {
                            Text("Top P: \(top_p, specifier: "%.2f")")
                        }

                        Stepper(value: $top_k, in: 0...200, step: 5) {
                            Text("Top K: \(Int(top_k))")
                        }

                        Stepper(value: $repeatPenalty, in: 0.5...2.0, step: 0.05) {
                            Text("Repeat Penalty: \(repeatPenalty, specifier: "%.2f")")
                        }

                        Stepper(value: $maxTokens, in: 1...2048, step: 16) {
                            Text("Max Tokens: \(maxTokens)")
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

