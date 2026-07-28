//
//  SourcePill.swift
//  FrontendAI
//
//  Created by macbook on 12.07.2026.
//

import SwiftUI

struct SourcePill: View {
    var text: String
    var icon: Image?
    
    var body: some View {
        HStack {
            Image("AICompanyHunyuan")
                .resizable()
                .frame(width: 20, height: 20)
            Text(text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
        }
        .glassEffect(.regular.tint(.black.opacity(1.0)).interactive())
    }
}

#Preview {
    SourcePill(text: "testlabel.com")
}
