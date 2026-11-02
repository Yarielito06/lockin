import Foundation

/// How often a routine item is due. Shared by the app and the widget.
enum SlotSchedule: Codable, Hashable {
    case daily
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    case days(Set<Int>)
    /// Any days, this many times per week.
    case perWeek(Int)

    /// Due on this date? A weekly item stays due until its quota is met (and on the day it was done).
    func isDue(slotID: UUID, on date: Date, in days: SharedCompletions.Days) -> Bool {
        switch self {
        case .daily:
            return true
        case .days(let weekdays):
            return weekdays.contains(Calendar.current.component(.weekday, from: date))
        case .perWeek(let target):
            if SharedCompletions.isDone(slotID, on: date, in: days) { return true }
            return doneThisWeek(slotID: slotID, upTo: date, in: days) < target
        }
    }

    /// Weekly items count towards a quota rather than a daily streak.
    var isWeeklyQuota: Bool {
        if case .perWeek = self { return true }
        return false
    }

    /// Times done this week up to and including `date`.
    func doneThisWeek(slotID: UUID, upTo date: Date, in days: SharedCompletions.Days) -> Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        var count = 0
        var day = week.start
        while day <= date {
            if SharedCompletions.isDone(slotID, on: day, in: days) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// "Every day", "Mon, Wed, Fri", "3× a week".
    var label: String {
        switch self {
        case .daily:
            return "Every day"
        case .days(let weekdays):
            if weekdays.count == 7 { return "Every day" }
            if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
            if weekdays == [1, 7] { return "Weekends" }
            let symbols = Calendar.current.shortWeekdaySymbols
            return Self.orderedWeekdays.filter(weekdays.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        case .perWeek(let target):
            return target == 1 ? "Once a week" : "\(target)× a week"
        }
    }

    /// Weekdays in the user's calendar order (e.g. Monday first in the UK).
    static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    /// 15 → "15 min", 60 → "1h", 90 → "1h 30".
    static func durationLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)"
    }
}
