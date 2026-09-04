import Foundation

enum APIServerSortOption: String, CaseIterable, Identifiable {
    case name
    case model

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name:
            "Name"
        case .model:
            "Model"
        }
    }

    var systemImage: String {
        switch self {
        case .name:
            "textformat"
        case .model:
            "cpu"
        }
    }
}
