import Foundation

/// A friend you lock in with — from Supabase when configured, otherwise on-device samples.
struct Friend: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var focusingUntil: Date?
    /// Group name while they're in a group session.
    var focusGroup: String?
    /// Free-time sessions have no fixed end; these show how long they've been going.
    var focusingSince: Date?
    var isFocusOpen: Bool = false
    var weekMinutes: Int = 0
    var streak: Int = 0

    /// Demo friends shown until friend sync exists. Their status is refreshed each launch.
    var isSample = false
    var demoFocusMinutes: Int?

    func isFocusing(at date: Date) -> Bool {
        guard let focusingUntil else { return false }
        return focusingUntil > date
    }

    func minutesLeft(at date: Date) -> Int {
        guard let focusingUntil else { return 0 }
        return max(0, Int((focusingUntil.timeIntervalSince(date) / 60).rounded(.up)))
    }

    /// "23 min left", or "1h 20m" for a free-time session; adds the group when there is one.
    func focusStatus(at date: Date) -> String {
        var text: String
        if isFocusOpen, let focusingSince {
            text = "\(Int(max(0, date.timeIntervalSince(focusingSince) / 60)).minutesLabel) so far"
        } else {
            text = "\(minutesLeft(at: date)) min left"
        }
        if let focusGroup { text += " · \(focusGroup)" }
        return text
    }

    static var samples: [Friend] {
        [
            Friend(name: "Sara Ahmed", weekMinutes: 340, streak: 12, isSample: true, demoFocusMinutes: 23),
            Friend(name: "Daniel Okafor", weekMinutes: 275, streak: 5, isSample: true, demoFocusMinutes: 48),
            Friend(name: "Maya Chen", weekMinutes: 190, streak: 3, isSample: true),
            Friend(name: "Omar Khan", weekMinutes: 120, streak: 0, isSample: true),
        ]
    }
}

/// A named set of friends to lock in with. On-device when offline; from the server when
/// connected, where the extra fields describe members, invites and a running group session.
struct StudyGroup: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// Everyone except you (joined and invited).
    var memberIDs: [UUID]
    var members: [GroupMember]?
    var isOwner: Bool?
    var sessionEndsAt: Date?
    var sessionStartedBy: UUID?
    var sessionStartedByName: String?
    /// For pending invites: who invited you.
    var invitedBy: String?

    func isSessionRunning(at date: Date) -> Bool {
        guard let sessionEndsAt else { return false }
        return sessionEndsAt > date
    }
}

struct GroupMember: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let isJoined: Bool
    let focusingUntil: Date?
}

/// A cheer a friend sent while you were locked in.
struct Cheer: Identifiable, Decodable, Equatable {
    let id: UUID
    let name: String
    let emoji: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case createdAt = "created_at"
    }
}
