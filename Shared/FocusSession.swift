import Foundation

/// A single focus session. Persisted in the App Group so the monitor extension
/// and a relaunched app can both see what is (or was) running.
struct FocusSession: Codable, Equatable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    /// Set when locking in with a group; nil for solo sessions.
    let groupName: String?
    /// "Free time": no fixed length. `endDate` is only a safety cap that the app keeps pushing back
    /// while the session runs, so the shields lift on their own if Lockin is never reopened.
    let isOpenEnded: Bool

    static let openEndedCap: TimeInterval = 24 * 3600

    private enum CodingKeys: String, CodingKey { case id, startDate, endDate, groupName, isOpenEnded }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        groupName = try c.decodeIfPresent(String.self, forKey: .groupName)
        isOpenEnded = try c.decodeIfPresent(Bool.self, forKey: .isOpenEnded) ?? false
    }

    /// A session that runs until you stop it.
    init(id: UUID = UUID(), openEndedFrom startDate: Date, capUntil: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = capUntil ?? startDate.addingTimeInterval(Self.openEndedCap)
        self.groupName = nil
        self.isOpenEnded = true
    }

    /// This session, ended at `date` — what gets recorded when you stop a free-time session.
    func ended(at date: Date) -> FocusSession {
        FocusSession(id: id, startDate: startDate, endDate: date, groupName: groupName)
    }

    func elapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startDate))
    }

    init(id: UUID = UUID(), startDate: Date, durationMinutes: Int, groupName: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        self.groupName = groupName
        self.isOpenEnded = false
    }

    /// For joining a group lock-in that ends at a fixed time.
    init(id: UUID = UUID(), startDate: Date, endDate: Date, groupName: String?) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.groupName = groupName
        self.isOpenEnded = false
    }

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var durationMinutes: Int { Int((duration / 60).rounded()) }

    func remaining(at date: Date) -> TimeInterval {
        max(0, endDate.timeIntervalSince(date))
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(startDate) / duration))
    }

    func isFinished(at date: Date) -> Bool {
        date >= endDate
    }
}
