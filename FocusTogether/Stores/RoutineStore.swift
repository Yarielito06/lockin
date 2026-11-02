import Foundation

/// The user's daily routines and which slots they've ticked off each day.
@MainActor
final class RoutineStore: ObservableObject {
    private enum Key {
        static let routines = "lockin.routines"
        static let completions = "lockin.routineCompletions"
    }

    @Published private(set) var routines: [Routine] {
        didSet {
            LocalStore.save(routines, forKey: Key.routines)
            refreshReminders()
        }
    }

    /// Completed slot IDs, keyed by day ("2026-11-01"). Stored in the App Group so the
    /// widget can tick slots too.
    @Published private var completions: SharedCompletions.Days {
        didSet {
            SharedCompletions.save(completions)
            if let data = try? JSONEncoder().encode(completions) { CloudSync.push(CloudSync.completionsKey, data: data) }
            refreshReminders()
        }
    }

    init() {
        routines = LocalStore.load([Routine].self, forKey: Key.routines) ?? []
        var stored = SharedCompletions.load()
        // One-time move from the app's own storage (before the widget could tick).
        if stored.isEmpty, let old = LocalStore.load([String: Set<UUID>].self, forKey: Key.completions) {
            stored = old
        }
        completions = stored
        pruneOldCompletions()
        refreshReminders()
        NotificationCenter.default.addObserver(forName: .lockinCloudApplied, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadFromCloud() }
        }

        #if DEBUG
        // Fills in the previous two days so streaks can be checked without waiting.
        if ProcessInfo.processInfo.arguments.contains("-seedStreak") {
            for offset in 1...2 {
                guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: .now) else { continue }
                completions[Self.dayKey(for: day)] = Set(routines.flatMap { $0.slots.map(\.id) })
            }
        }
        #endif
    }

    /// Newer routines or ticks arrived from another of your devices.
    private func reloadFromCloud() {
        if let fresh = LocalStore.load([Routine].self, forKey: Key.routines), fresh != routines { routines = fresh }
        let ticks = SharedCompletions.load()
        if ticks != completions { completions = ticks }
    }

    /// Re-plans notifications (prayer reminders roll a week ahead). Also called on app foreground.
    func refreshReminders() {
        ReminderScheduler.reschedule(routines) { slot, date in isDone(slot, on: date) }
    }

    /// Picks up ticks made from the widget while the app was in the background.
    func reloadSharedCompletions() {
        let latest = SharedCompletions.load()
        if latest != completions { completions = latest }
    }

    // MARK: Ticking slots

    func isDone(_ slot: RoutineSlot, on date: Date = .now) -> Bool {
        completions[Self.dayKey(for: date), default: []].contains(slot.id)
    }

    func toggle(_ slot: RoutineSlot) {
        let key = Self.dayKey(for: .now)
        var done = completions[key, default: []]
        if done.contains(slot.id) {
            done.remove(slot.id)
        } else {
            done.insert(slot.id)
        }
        completions[key] = done
    }

    /// Items due on a date — daily ones, today's weekdays, and weekly ones not yet done enough.
    func dueSlots(in routine: Routine, on date: Date = .now) -> [RoutineSlot] {
        routine.slots.filter { $0.effectiveSchedule.isDue(slotID: $0.id, on: date, in: completions) }
    }

    func doneCount(in routine: Routine) -> Int {
        dueSlots(in: routine).filter { isDone($0) }.count
    }

    /// For weekly items: how many times this week so far.
    func doneThisWeek(_ slot: RoutineSlot, on date: Date = .now) -> Int {
        slot.effectiveSchedule.doneThisWeek(slotID: slot.id, upTo: date, in: completions)
    }

    var todayProgress: (done: Int, total: Int) {
        let total = routines.reduce(0) { $0 + dueSlots(in: $1).count }
        let done = routines.reduce(0) { $0 + doneCount(in: $1) }
        return (done, total)
    }

    /// The first day anything was ticked (or today). Earlier days show as "no data", not missed.
    var firstTrackedDay: Date {
        let calendar = Calendar.current
        let earliest = completions.filter { !$0.value.isEmpty }.keys.min()
        guard let earliest else { return calendar.startOfDay(for: .now) }
        let parts = earliest.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return calendar.startOfDay(for: .now) }
        return date
    }

    /// Done and due across all routines on a day.
    func progress(on date: Date) -> (done: Int, due: Int) {
        let due = routines.flatMap { dueSlots(in: $0, on: date) }
        return (due.filter { isDone($0, on: date) }.count, due.count)
    }

    // MARK: Streaks

    /// Items a day's streak depends on: everything due that day except weekly quotas,
    /// which can be done on any day.
    private func streakSlots(in routine: Routine, on date: Date) -> [RoutineSlot] {
        dueSlots(in: routine, on: date).filter { !$0.effectiveSchedule.isWeeklyQuota }
    }

    /// True when every item due that day is ticked. Days with nothing due return false.
    func isComplete(_ routine: Routine, on date: Date = .now) -> Bool {
        let due = streakSlots(in: routine, on: date)
        guard !due.isEmpty else { return false }
        let done = completions[Self.dayKey(for: date), default: []]
        return due.allSatisfy { done.contains($0.id) }
    }

    /// Consecutive complete days ending today — or ending yesterday while today is still
    /// in progress. Rest days (nothing due) are skipped rather than breaking the streak.
    func streak(for routine: Routine, now: Date = .now) -> Int {
        let calendar = Calendar.current
        var day = now
        if !isComplete(routine, on: day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        for _ in 0..<400 {
            if streakSlots(in: routine, on: day).isEmpty {
                // Rest day: neither counts nor breaks the streak.
            } else if isComplete(routine, on: day) {
                count += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: Editing

    func save(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    /// Puts a deleted routine back where it was (the undo after a swipe).
    func restore(_ routine: Routine, at index: Int) {
        guard !routines.contains(where: { $0.id == routine.id }) else { return }
        routines.insert(routine, at: min(max(0, index), routines.count))
    }

    func delete(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }
    }

    // MARK: Private

    private static func dayKey(for date: Date) -> String {
        SharedCompletions.dayKey(for: date)
    }

    /// Keeps a year of history (enough for long streaks). Zero-padded keys sort chronologically as strings.
    private func pruneOldCompletions() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: .now) else { return }
        let oldest = Self.dayKey(for: cutoff)
        completions = completions.filter { $0.key >= oldest }
    }
}
