import Foundation

struct DataUsageBucket: Identifiable {
    let date: Date
    let byteCount: Int

    var id: Date {
        date
    }
}
