import Foundation

struct SessionRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    let endDate: Date
    let minutes: Int
    let groupName: String?
}

/// Completed focus sessions, used for stats, streaks and the weekly leaderboard.
@MainActor
final class HistoryStore: ObservableObject {
    private static let key = "lockin.sessionHistory"

    @Published private(set) var records: [SessionRecord] {
        didSet { LocalStore.save(records, forKey: Self.key) }
    }

    init() {
        records = LocalStore.load([SessionRecord].self, forKey: Self.key) ?? []
    }

    func record(_ session: FocusSession) {
        records.append(SessionRecord(endDate: session.endDate, minutes: session.durationMinutes, groupName: session.groupName))
    }

    /// Completed sessions that ended on the given day.
    func sessions(on date: Date) -> [SessionRecord] {
        records.filter { Calendar.current.isDate($0.endDate, inSameDayAs: date) }
    }

    /// Every minute you've ever locked in for.
    var totalMinutes: Int { records.reduce(0) { $0 + $1.minutes } }

    var todayMinutes: Int {
        minutes(since: Calendar.current.startOfDay(for: .now))
    }

    var weekMinutes: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return minutes(since: start)
    }

    /// Consecutive days with at least one completed session, ending today (or yesterday,
    /// so the streak doesn't look broken before today's first session).
    var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(records.map { calendar.startOfDay(for: $0.endDate) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private func minutes(since start: Date) -> Int {
        records.filter { $0.endDate >= start }.reduce(0) { $0 + $1.minutes }
    }
}
