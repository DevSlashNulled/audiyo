import Foundation

struct RecentSwitch: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var direction: AudioDirection
    var fromUID: String?
    var toUID: String
    var reason: String

    init(id: UUID = UUID(), date: Date = Date(), direction: AudioDirection, fromUID: String?, toUID: String, reason: String) {
        self.id = id
        self.date = date
        self.direction = direction
        self.fromUID = fromUID
        self.toUID = toUID
        self.reason = reason
    }
}

struct RecentSwitches: Equatable {
    private(set) var entries: [RecentSwitch] = []
    var limit: Int = 8

    init(limit: Int = 8) {
        self.limit = limit
    }

    mutating func record(_ entry: RecentSwitch) {
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    mutating func removeAll() {
        entries.removeAll()
    }
}
