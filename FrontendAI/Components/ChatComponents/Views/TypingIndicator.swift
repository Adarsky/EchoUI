//
//  TypingIndicator.swift
//  FrontendAI
//
//  Created by macbook on 03.07.2025.
//


//
//  TypingIndicator.swift
//  FrontendAI
//
//  Created by macbook on 30.03.2025.
//

import SwiftUI

/// Мигающий кружок, показывающий «бот печатает».
struct TypingIndicator: View {
    @State private var scale: CGFloat = 0.5

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.6))
            .frame(width: 12, height: 12)
            .scaleEffect(scale)
            .opacity(Double(scale))
            .animation(
                .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                value: scale
            )
            .onAppear { scale = 1.0 }
    }
}
