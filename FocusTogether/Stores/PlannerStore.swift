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
        NotificationCenter.default.addObserver(forName: .lockinCloudApplied, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadFromCloud() }
        }
    }

    private func reloadFromCloud() {
        if let fresh = LocalStore.load([PlanItem].self, forKey: Key.items), fresh != items { items = fresh }
        if let fresh = LocalStore.load([Goal].self, forKey: Key.goals), fresh != goals { goals = fresh }
    }

    private let calendar = Calendar.current

    // MARK: Reading

    /// Everything that covers a day: periods first, then single items by time.
    func items(on date: Date) -> [PlanItem] {
        func sortKey(_ item: PlanItem) -> Date { item.hasTime ? item.date : calendar.startOfDay(for: item.date) }
        return items.filter { $0.covers(date) }.sorted {
            if $0.isPeriod != $1.isPeriod { return $0.isPeriod }
            return sortKey($0) < sortKey($1)
        }
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
            .filter { !$0.isDone && $0.lastDay >= today.addingTimeInterval(-7 * 86_400) }
            .map { UpcomingEntry(id: $0.id, title: $0.title, date: $0.date, endDate: $0.endDate, symbol: $0.kind.symbol, color: $0.kind.color, isGoal: false, item: $0, goal: nil) }
        entries += activeGoals.map {
            UpcomingEntry(id: $0.id, title: $0.title, date: $0.targetDate, symbol: $0.symbol, color: Theme.accent, isGoal: true, item: nil, goal: $0)
        }
        return Array(entries.sorted { $0.date < $1.date }.prefix(limit))
    }

    // MARK: Editing

    func save(_ item: PlanItem) {
        var item = item
        if !item.hasTime { item.date = calendar.startOfDay(for: item.date) }
        // A period always ends on or after its first day.
        if let end = item.endDate {
            let endDay = calendar.startOfDay(for: end)
            item.endDate = endDay > calendar.startOfDay(for: item.date) ? endDay : nil
        }
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
