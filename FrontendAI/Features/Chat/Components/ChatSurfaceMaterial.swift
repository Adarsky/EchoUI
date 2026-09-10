enum ChatSurfaceMaterial: String, Codable, CaseIterable, Identifiable {
    case ultraThinMaterial
    case glass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ultraThinMaterial:
            "Ultra Thin Material"
        case .glass:
            "Glass"
        }
    }
}
