//
//  LoadScreen.swift
//  FrontendAI
//
//  Created by macbook on 04.09.2026.
//

import SwiftUI

struct LoadScreen: View {
    var body: some View {
        VStack {
            Image("AppIconPreview")
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
        }
    }
}

#Preview {
    LoadScreen()
}
