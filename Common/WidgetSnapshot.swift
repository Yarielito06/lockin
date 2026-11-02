import Foundation

/// Everything the widget shows, written by the app to the App Group whenever it changes.
/// The widget can't read the app's own stores, so this is the hand-off.
struct WidgetSnapshot: Codable, Equatable {
    struct PrayerTime: Codable, Equatable {
        let name: String
        let date: Date
    }

    /// A routine as the routines widget shows it. Ticks are read live from `SharedCompletions`.
    struct RoutineInfo: Codable, Equatable {
        struct Slot: Codable, Equatable {
            let id: UUID
            let name: String
            /// Today's prayer time, for Salah slots.
            let time: Date?
            /// "2L · 15 min".
            var detail: String? = nil
            var schedule: SlotSchedule = .daily
        }

        /// Items due on a date, given the shared ticks.
        func dueSlots(on date: Date, in days: SharedCompletions.Days) -> [Slot] {
            slots.filter { $0.schedule.isDue(slotID: $0.id, on: date, in: days) }
        }

        let id: UUID
        let name: String
        let symbol: String
        let slots: [Slot]
    }

    /// Start of the day the routine counts belong to; counts from an earlier day read as 0 done.
    var day: Date
    var routinesDone: Int
    var routinesTotal: Int

    var placeName: String?
    /// Today's prayers plus tomorrow's Fajr, so "next prayer" is always answerable.
    var prayers: [PrayerTime]

    var sessionStart: Date?
    var sessionEnd: Date?
    var groupName: String?
    var sessionOpenEnded: Bool? = nil

    var focusMinutesToday: Int
    var streakDays: Int

    var routines: [RoutineInfo]

    static let empty = WidgetSnapshot(
        day: Calendar.current.startOfDay(for: .now), routinesDone: 0, routinesTotal: 0,
        placeName: nil, prayers: [], sessionStart: nil, sessionEnd: nil, groupName: nil,
        focusMinutesToday: 0, streakDays: 0, routines: []
    )

    // MARK: Reading at a point in time

    func routinesDone(on date: Date) -> Int {
        // Count live from the shared ticks, so ticking in the widget updates everything at once.
        if !routines.isEmpty {
            let days = SharedCompletions.load()
            return routines.flatMap { $0.dueSlots(on: date, in: days) }
                .filter { SharedCompletions.isDone($0.id, on: date, in: days) }.count
        }
        return Calendar.current.isDate(day, inSameDayAs: date) ? routinesDone : 0
    }

    /// Items due today (rest days and weekly quotas already met don't count).
    func routinesTotal(on date: Date) -> Int {
        guard !routines.isEmpty else { return routinesTotal }
        let days = SharedCompletions.load()
        return routines.reduce(0) { $0 + $1.dueSlots(on: date, in: days).count }
    }

    func nextPrayer(after date: Date) -> PrayerTime? {
        prayers.first { $0.date > date }
    }

    func isLocked(at date: Date) -> Bool {
        guard let sessionEnd else { return false }
        return sessionEnd > date
    }

    func sessionProgress(at date: Date) -> Double {
        guard let start = sessionStart, let end = sessionEnd, end > start else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    // MARK: Storage

    private static let key = "lockin.widgetSnapshot"

    static func load() -> WidgetSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults.set(data, forKey: Self.key)
    }
}
