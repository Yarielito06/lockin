import Foundation

/// A shared weekly focus goal for a group.
struct GroupChallenge: Identifiable, Decodable, Equatable {
    struct Member: Decodable, Equatable, Identifiable {
        let id: UUID
        let name: String
        let minutes: Int
    }

    let groupID: UUID
    let groupName: String
    let title: String
    let targetMinutes: Int
    let weekStart: String
    let createdBy: UUID?
    let createdByName: String?
    let members: [Member]

    var id: UUID { groupID }

    enum CodingKeys: String, CodingKey {
        case title, members
        case groupID = "group_id"
        case groupName = "group_name"
        case targetMinutes = "target_minutes"
        case weekStart = "week_start"
        case createdBy = "created_by"
        case createdByName = "created_by_name"
    }

    var isCurrentWeek: Bool { weekStart == Backend.currentWeekKey() }

    /// Everyone's minutes added up; `myMinutes` replaces your own with the live number from this phone.
    func totalMinutes(me: UUID?, myMinutes: Int) -> Int {
        members.reduce(0) { $0 + ($1.id == me ? max($1.minutes, myMinutes) : $1.minutes) }
    }

    func fraction(me: UUID?, myMinutes: Int) -> Double {
        min(1, Double(totalMinutes(me: me, myMinutes: myMinutes)) / Double(max(1, targetMinutes)))
    }
}
