import Foundation
import Supabase

/// The Supabase connection, configured from Info.plist (filled from Config/Signing.xcconfig).
/// `client` is nil when no project is configured — the app then runs with on-device sample friends.
enum Backend {
    static let client: SupabaseClient? = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "LockinSupabaseHost") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "LockinSupabaseKey") as? String,
              !host.isEmpty, !key.isEmpty,
              let url = URL(string: "https://\(host)")
        else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }()

    /// The ISO week the published `week_minutes` belong to, e.g. "2026-10-26".
    /// ISO weeks start on Monday everywhere, so friends in different countries agree.
    static func currentWeekKey(now: Date = .now) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// A row of `public.profiles`.
struct ProfileRow: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var inviteCode: String
    var focusingUntil: Date?
    var focusGroup: String?
    var focusSince: Date?
    var focusOpen: Bool?
    var weekMinutes: Int
    var weekStart: String?
    var streak: Int

    enum CodingKeys: String, CodingKey {
        case focusSince = "focus_since"
        case focusOpen = "focus_open"
        case id
        case displayName = "display_name"
        case inviteCode = "invite_code"
        case focusingUntil = "focusing_until"
        case focusGroup = "focus_group"
        case weekMinutes = "week_minutes"
        case weekStart = "week_start"
        case streak
    }

    /// As shown in the Friends tab. Minutes from a previous week count as 0.
    var asFriend: Friend {
        Friend(
            id: id,
            name: displayName,
            focusingUntil: focusingUntil,
            focusGroup: focusGroup,
            focusingSince: focusSince,
            isFocusOpen: focusOpen ?? false,
            weekMinutes: weekStart == Backend.currentWeekKey() ? weekMinutes : 0,
            streak: streak
        )
    }
}

/// The columns a user may change on their own profile (see the grants in Backend/schema.sql).
struct ProfileStatusUpdate: Encodable, Equatable {
    var focusingUntil: Date?
    var focusGroup: String?
    var focusSince: Date?
    var focusOpen: Bool
    var weekMinutes: Int
    var weekStart: String
    var streak: Int
    var updatedAt = Date()

    enum CodingKeys: String, CodingKey {
        case focusSince = "focus_since"
        case focusOpen = "focus_open"
        case focusingUntil = "focusing_until"
        case focusGroup = "focus_group"
        case weekMinutes = "week_minutes"
        case weekStart = "week_start"
        case streak
        case updatedAt = "updated_at"
    }

    /// Encodes nils explicitly so finishing a session clears `focusing_until` on the server.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusingUntil, forKey: .focusingUntil)
        try container.encode(focusGroup, forKey: .focusGroup)
        try container.encode(focusSince, forKey: .focusSince)
        try container.encode(focusOpen, forKey: .focusOpen)
        try container.encode(weekMinutes, forKey: .weekMinutes)
        try container.encode(weekStart, forKey: .weekStart)
        try container.encode(streak, forKey: .streak)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// Equal apart from the timestamp — used to skip redundant uploads.
    func sameStatus(as other: ProfileStatusUpdate) -> Bool {
        focusingUntil == other.focusingUntil && focusGroup == other.focusGroup
            && focusSince == other.focusSince && focusOpen == other.focusOpen
            && weekMinutes == other.weekMinutes && weekStart == other.weekStart && streak == other.streak
    }
}

// MARK: Requests and groups (`my_social()`)

/// Someone on the other end of a friend request.
struct PersonRef: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
}

/// Everything returned by `my_social()`.
struct SocialSnapshot: Decodable {
    let incoming: [PersonRef]
    let outgoing: [PersonRef]
    let groups: [RemoteGroup]
    let invites: [RemoteGroup]
}

struct RemoteGroup: Decodable {
    let id: UUID
    let name: String
    let ownerID: UUID
    let sessionEndsAt: Date?
    let sessionStartedBy: UUID?
    let sessionStartedByName: String?
    let invitedBy: String?
    let members: [RemoteMember]

    enum CodingKeys: String, CodingKey {
        case id, name, members
        case ownerID = "owner_id"
        case sessionEndsAt = "session_ends_at"
        case sessionStartedBy = "session_started_by"
        case sessionStartedByName = "session_started_by_name"
        case invitedBy = "invited_by"
    }

    struct RemoteMember: Decodable {
        let id: UUID
        let name: String
        let status: String
        let focusingUntil: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, status
            case focusingUntil = "focusing_until"
        }
    }

    func asGroup(me: UUID?) -> StudyGroup {
        StudyGroup(
            id: id,
            name: name,
            memberIDs: members.map(\.id).filter { $0 != me },
            members: members.map {
                GroupMember(id: $0.id, name: $0.name, isJoined: $0.status == "joined", focusingUntil: $0.focusingUntil)
            },
            isOwner: ownerID == me,
            sessionEndsAt: sessionEndsAt,
            sessionStartedBy: sessionStartedBy,
            sessionStartedByName: sessionStartedByName,
            invitedBy: invitedBy
        )
    }
}

/// Result of `send_friend_request`.
struct FriendRequestResult: Decodable {
    let name: String
    let status: String
}
