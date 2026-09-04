import Foundation

struct APIServerGroup: Identifiable {
    let id: String
    let title: String
    let isOfficial: Bool
    let servers: [APIServer]
}
