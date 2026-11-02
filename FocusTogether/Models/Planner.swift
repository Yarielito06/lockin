import SwiftUI

/// What kind of thing is on the calendar.
enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case deadline, exam, event, task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deadline: "Deadline"
        case .exam: "Exam"
        case .event: "Event"
        case .task: "To-do"
        }
    }

    var symbol: String {
        switch self {
        case .deadline: "flag.fill"
        case .exam: "graduationcap.fill"
        case .event: "calendar"
        case .task: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .deadline: Color(red: 0.93, green: 0.30, blue: 0.30)
        case .exam: Color(red: 0.55, green: 0.38, blue: 0.95)
        case .event: Color(red: 0.20, green: 0.55, blue: 0.95)
        case .task: Theme.accent
        }
    }
}

/// A deadline, exam, event or to-do on a date.
struct PlanItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var kind: PlanKind = .deadline
    /// The day (start of day) when `hasTime` is false, otherwise the exact moment.
    var date: Date
    var hasTime = false
    var note = ""
    var isDone = false
    /// For a period (like "submit between 9 and 13 Nov"): the last day, start of day. nil for a single day.
    var endDate: Date?
    /// Remind me this many days before it starts (0 = don't).
    var leadDays = 3
    /// A short note every morning until it's done.
    var nudge = true

    enum CodingKeys: String, CodingKey { case id, title, kind, date, hasTime, note, isDone, endDate, leadDays, nudge }

    init(id: UUID = UUID(), title: String, kind: PlanKind = .deadline, date: Date) {
        self.id = id
        self.title = title
        self.kind = kind
        self.date = date
    }

    // Older saved items don't have the newest fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        kind = try c.decodeIfPresent(PlanKind.self, forKey: .kind) ?? .deadline
        date = try c.decode(Date.self, forKey: .date)
        hasTime = try c.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        leadDays = try c.decodeIfPresent(Int.self, forKey: .leadDays) ?? 3
        nudge = try c.decodeIfPresent(Bool.self, forKey: .nudge) ?? true
    }

    var isPeriod: Bool {
        guard let endDate else { return false }
        return Calendar.current.startOfDay(for: endDate) > Calendar.current.startOfDay(for: date)
    }

    /// The last day it covers.
    var lastDay: Date { Calendar.current.startOfDay(for: endDate ?? date) }

    /// Number of days it covers.
    var dayCount: Int {
        let calendar = Calendar.current
        return (calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: lastDay).day ?? 0) + 1
    }

    func covers(_ day: Date) -> Bool {
        let calendar = Calendar.current
        let d = calendar.startOfDay(for: day)
        return d >= calendar.startOfDay(for: date) && d <= lastDay
    }

    /// "Thu 13 Nov", or "9 – 13 Nov" for a period.
    var dateLabel: String {
        let calendar = Calendar.current
        guard isPeriod else { return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
        let sameMonth = calendar.isDate(date, equalTo: lastDay, toGranularity: .month)
        let start = sameMonth ? date.formatted(.dateTime.day()) : date.formatted(.dateTime.day().month(.abbreviated))
        return "\(start) – \(lastDay.formatted(.dateTime.day().month(.abbreviated)))"
    }

    /// The moment to remind you.
    var fireDate: Date {
        if hasTime { return date }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }
}

/// Something you're working towards, like "Study — exam day on 23 November".
struct Goal: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var symbol: String = "graduationcap.fill"
    var targetDate: Date
    var createdAt = Date()
    var note = ""

    static let symbols = [
        "graduationcap.fill", "book.fill", "dumbbell.fill", "figure.run", "briefcase.fill",
        "pencil.and.outline", "heart.fill", "star.fill", "airplane", "flag.checkered",
    ]

    /// Whole days from today to the target day (0 on the day, negative after).
    func daysLeft(from now: Date = .now) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: targetDate)).day ?? 0
    }

    /// How far through the time between setting the goal and the day.
    func timeProgress(at now: Date = .now) -> Double {
        let total = targetDate.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(createdAt) / total))
    }
}

/// One line in an "Upcoming" list: either a goal's day or a planned item.
struct UpcomingEntry: Identifiable {
    let id: UUID
    let title: String
    let date: Date
    /// Last day, for periods.
    var endDate: Date?
    let symbol: String
    let color: Color
    let isGoal: Bool
    let item: PlanItem?
    let goal: Goal?

    var isPeriod: Bool { item?.isPeriod ?? false }

    /// "Thu 13 Nov" or "9 – 13 Nov".
    var dateLabel: String {
        item?.dateLabel ?? date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// 0...1 through a period that's under way; nil otherwise.
    func progress(now: Date = .now) -> Double? {
        guard let item, item.isPeriod else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard item.covers(today) else { return nil }
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: item.date), to: today).day ?? 0
        return Double(elapsed + 1) / Double(item.dayCount)
    }

    /// "Today", "Tomorrow", "In 5 days", or for a period under way "Ends in 3 days".
    func relativeLabel(now: Date = .now) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if let item, item.isPeriod, item.covers(today) {
            let left = calendar.dateComponents([.day], from: today, to: item.lastDay).day ?? 0
            switch left {
            case 0: return "Ends today"
            case 1: return "Ends tomorrow"
            default: return "Ends in \(left) days"
            }
        }
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "\(-days)d ago"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }
}
