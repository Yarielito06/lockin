import Foundation
import SwiftUI

/// Your goals, deadlines and events. Saved on the device; reminders are local notifications.
@MainActor
final class PlannerStore: ObservableObject {
    private enum Key {
        static let items = "lockin.planItems"
        static let goals = "lockin.goals"
    }

    @Published private(set) var items: [PlanItem] {
        didSet { LocalStore.save(items, forKey: Key.items); scheduleReminders() }
    }

    @Published private(set) var goals: [Goal] {
        didSet { LocalStore.save(goals, forKey: Key.goals); scheduleReminders() }
    }

    init() {
        items = LocalStore.load([PlanItem].self, forKey: Key.items) ?? []
        goals = LocalStore.load([Goal].self, forKey: Key.goals) ?? []
    }

    private let calendar = Calendar.current

    // MARK: Reading

    func items(on date: Date) -> [PlanItem] {
        items.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { ($0.hasTime ? $0.date : calendar.startOfDay(for: $0.date)) < ($1.hasTime ? $1.date : calendar.startOfDay(for: $1.date)) }
    }

    func goals(on date: Date) -> [Goal] {
        goals.filter { calendar.isDate($0.targetDate, inSameDayAs: date) }
    }

    func hasItems(on date: Date) -> Bool { !items(on: date).isEmpty }
    func hasGoal(on date: Date) -> Bool { !goals(on: date).isEmpty }

    /// Goals that haven't passed yet, soonest first.
    var activeGoals: [Goal] {
        goals.filter { $0.daysLeft() >= 0 }.sorted { $0.targetDate < $1.targetDate }
    }

    /// Things still ahead (and anything overdue that isn't done), soonest first.
    func upcoming(limit: Int = 8, now: Date = .now) -> [UpcomingEntry] {
        let today = calendar.startOfDay(for: now)
        var entries: [UpcomingEntry] = items
            .filter { !$0.isDone && calendar.startOfDay(for: $0.date) >= today.addingTimeInterval(-7 * 86_400) }
            .map { UpcomingEntry(id: $0.id, title: $0.title, date: $0.date, symbol: $0.kind.symbol, color: $0.kind.color, isGoal: false, item: $0, goal: nil) }
        entries += activeGoals.map {
            UpcomingEntry(id: $0.id, title: $0.title, date: $0.targetDate, symbol: $0.symbol, color: Theme.accent, isGoal: true, item: nil, goal: $0)
        }
        return Array(entries.sorted { $0.date < $1.date }.prefix(limit))
    }

    // MARK: Editing

    func save(_ item: PlanItem) {
        var item = item
        if !item.hasTime { item.date = calendar.startOfDay(for: item.date) }
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }
    }

    func delete(_ item: PlanItem) { items.removeAll { $0.id == item.id } }

    func toggle(_ item: PlanItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
    }

    func save(_ goal: Goal) {
        var goal = goal
        goal.targetDate = calendar.startOfDay(for: goal.targetDate)
        if let index = goals.firstIndex(where: { $0.id == goal.id }) { goals[index] = goal } else { goals.append(goal) }
    }

    func delete(_ goal: Goal) { goals.removeAll { $0.id == goal.id } }

    func scheduleReminders() {
        ReminderScheduler.reschedulePlanner(items: items, goals: goals)
    }
}
