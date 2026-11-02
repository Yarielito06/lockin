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
    let symbol: String
    let color: Color
    let isGoal: Bool
    let item: PlanItem?
    let goal: Goal?

    /// "Today", "Tomorrow", "In 5 days".
    func relativeLabel(now: Date = .now) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "\(-days)d ago"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }
}
