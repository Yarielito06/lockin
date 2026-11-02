import Foundation

/// Which routine slots are ticked, per day — kept in the App Group so the app and the
/// home-screen widget can both read and tick them.
enum SharedCompletions {
    typealias Days = [String: Set<UUID>]

    private static let key = "lockin.routineCompletions"

    static func load() -> Days {
        guard let data = AppGroup.defaults.data(forKey: key),
              let days = try? JSONDecoder().decode(Days.self, from: data)
        else { return [:] }
        return days
    }

    static func save(_ days: Days) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func isDone(_ slotID: UUID, on date: Date, in days: Days) -> Bool {
        days[dayKey(for: date), default: []].contains(slotID)
    }

    /// Ticks or unticks a slot for the given day (used by the widget's button).
    static func toggle(_ slotID: UUID, on date: Date) {
        var days = load()
        let key = dayKey(for: date)
        var done = days[key, default: []]
        if done.contains(slotID) { done.remove(slotID) } else { done.insert(slotID) }
        days[key] = done
        save(days)
    }

    /// "2026-11-01" — zero-padded, so keys also sort chronologically as strings.
    static func dayKey(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
