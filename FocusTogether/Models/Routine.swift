import Foundation

/// Something the user does every day, made of slots they tick off — e.g. Salah with
/// Fajr, Dhuhr, Asr, Maghrib and Isha, or a habit list with Water, Move and Read.
struct Routine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var slots: [RoutineSlot]
    /// Set for Salah routines that show calculated prayer times.
    var prayerSettings: PrayerSettings?
    /// Salah only: minutes before each prayer to notify (0 = at the time); nil = off.
    var prayerReminderMinutes: Int?
    /// Other routines: one reminder at this time every day; nil = off.
    var reminderTime: ReminderTime?
}

struct ReminderTime: Codable, Hashable {
    var hour: Int
    var minute: Int
}

/// One item in a routine: "Water · 2L · every day", "Gym · 1h · 3× a week".
struct RoutineSlot: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Links a slot to a calculated prayer time.
    var prayer: PrayerName?
    /// Short detail, e.g. "2L", "Chapter 3", "5 km".
    var note: String?
    /// How long it takes, e.g. 15 or 120.
    var minutes: Int?
    /// nil means every day (items saved before schedules existed).
    var schedule: SlotSchedule?

    var effectiveSchedule: SlotSchedule { schedule ?? .daily }

    /// "2L · 15 min" — what's shown under the item's name.
    var detailText: String? {
        let parts = [note?.trimmingCharacters(in: .whitespaces), minutes.map(SlotSchedule.durationLabel)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// The kinds offered when adding a routine. Every routine stays fully editable afterwards.
enum RoutineKind: CaseIterable, Identifiable {
    case prayer, habits, study, fitness, custom

    var id: Self { self }

    var title: String {
        switch self {
        case .prayer: "Prayer"
        case .habits: "Habits"
        case .study: "Study"
        case .fitness: "Fitness"
        case .custom: "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .prayer: "Daily prayers for your faith"
        case .habits: "Water 2L, read 15 min, sleep…"
        case .study: "Study 2 hours, homework, revise…"
        case .fitness: "Gym, run, stretch — on your days"
        case .custom: "Anything you do every day"
        }
    }

    var symbol: String {
        switch self {
        case .prayer: "sun.horizon"
        case .habits: "leaf"
        case .study: "graduationcap"
        case .fitness: "dumbbell"
        case .custom: "square.and.pencil"
        }
    }
}

enum Tradition: CaseIterable, Identifiable {
    case islam, christian, other

    var id: Self { self }

    var title: String {
        switch self {
        case .islam: "Islam"
        case .christian: "Christian"
        case .other: "Other"
        }
    }

    var subtitle: String {
        switch self {
        case .islam: "Five daily prayers, with times for where you are"
        case .christian: "Morning and evening prayer, Bible reading"
        case .other: "Set up your own prayers"
        }
    }
}

/// Ready-made drafts that open in the editor.
enum RoutineDrafts {
    static func salah(settings: PrayerSettings?) -> Routine {
        Routine(
            name: "Salah",
            symbol: "moon.stars",
            slots: PrayerName.allCases.map { RoutineSlot(name: $0.title, prayer: $0) },
            prayerSettings: settings
        )
    }

    static let christianPrayer = make("Prayer", "sun.max", [
        RoutineSlot(name: "Morning prayer"),
        RoutineSlot(name: "Evening prayer"),
        RoutineSlot(name: "Bible", note: "1 chapter", minutes: 15),
    ])
    static let otherPrayer = make("Prayer", "sparkles", [
        RoutineSlot(name: "Morning"),
        RoutineSlot(name: "Evening"),
    ])
    static let habits = make("Habits", "leaf", [
        RoutineSlot(name: "Water", note: "2L"),
        RoutineSlot(name: "Read", minutes: 15),
        RoutineSlot(name: "Walk", note: "8k steps"),
    ])
    static let study = make("Study", "graduationcap", [
        RoutineSlot(name: "Study", minutes: 120),
        RoutineSlot(name: "Homework"),
        RoutineSlot(name: "Revise", minutes: 30, schedule: .perWeek(3)),
    ])
    static let fitness = make("Fitness", "dumbbell", [
        RoutineSlot(name: "Gym", minutes: 60, schedule: .days([2, 4, 6])),
        RoutineSlot(name: "Run", note: "5 km", minutes: 30, schedule: .perWeek(2)),
        RoutineSlot(name: "Stretch", minutes: 10),
    ])
    static let custom = make("", "checkmark.circle", [])

    private static func make(_ name: String, _ symbol: String, _ slots: [RoutineSlot]) -> Routine {
        Routine(name: name, symbol: symbol, slots: slots)
    }

    static let symbols = [
        "moon.stars", "sun.max", "sparkles", "sun.horizon", "book",
        "leaf", "drop", "figure.walk", "dumbbell", "graduationcap",
        "brain.head.profile", "heart", "bed.double", "fork.knife", "checkmark.circle",
    ]
}
