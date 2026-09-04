import SwiftUI

enum ChatFolderColor: String, CaseIterable, Identifiable {
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal

    static let defaultValue: ChatFolderColor = .blue

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .blue:
            Color(red: 0.13, green: 0.35, blue: 0.78)
        case .indigo:
            Color(red: 0.29, green: 0.25, blue: 0.66)
        case .purple:
            Color(red: 0.48, green: 0.21, blue: 0.68)
        case .pink:
            Color(red: 0.68, green: 0.13, blue: 0.34)
        case .red:
            Color(red: 0.72, green: 0.14, blue: 0.16)
        case .orange:
            Color(red: 0.61, green: 0.24, blue: 0.04)
        case .yellow:
            Color(red: 0.43, green: 0.32, blue: 0.00)
        case .green:
            Color(red: 0.08, green: 0.37, blue: 0.19)
        case .teal:
            Color(red: 0.00, green: 0.36, blue: 0.39)
        }
    }
}
