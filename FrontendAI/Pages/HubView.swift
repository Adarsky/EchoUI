//
//  HubView.swift
//  FrontendAI
//
//  Created by macbook on 20.10.2025.
//

// There will be Janitor's ai bots ;3 magnifyingglass.circle.fill
import SwiftUI

struct HubView: View {
    @Binding var seatchText: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack{
                    Text("Echo UI")
                        .font(.title)
                        .bold()
                    Text("Janitor AI HUB")
                        .font(.caption)
                        .bold()
                }
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.10))
                HStack {
                    TextField("Search...", text: $seatchText)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color(.systemGray6))
                            
                            
                        )
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 45))
                    }
                }
                .padding()
            Spacer()
        }
    }
}


#Preview {
    @State var searchText = ""
    return HubView(seatchText: $searchText)
}

