import SwiftUI
import WidgetKit

@main
struct LockinWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockinWidget()
        LockinRoutinesWidget()
        LockinFriendsWidget()
        LockinGoalWidget()
        LockinLiveActivity()
    }
}

struct LockinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockinWidget", provider: LockinProvider()) { entry in
            LockinWidgetView(entry: entry)
        }
        .configurationDisplayName("Lockin")
        .description("Your day at a glance, and the time left while you're locked in.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct LockinEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Widget gallery / placeholder: show sample ticks instead of the real ones.
    var isPreview = false
}

/// One entry now, then one at each moment the content changes on its own:
/// each upcoming prayer, the session end and midnight (routine counts reset).
struct LockinProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockinEntry {
        LockinEntry(date: .now, snapshot: .preview, isPreview: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockinEntry) -> Void) {
        if context.isPreview {
            completion(LockinEntry(date: .now, snapshot: .preview, isPreview: true))
        } else {
            completion(LockinEntry(date: .now, snapshot: WidgetSnapshot.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockinEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.load()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(3600)

        var dates: Set<Date> = [now, midnight]
        snapshot.prayers.map(\.date).filter { $0 > now && $0 <= midnight }.forEach { dates.insert($0) }
        if let end = snapshot.sessionEnd, end > now { dates.insert(end) }

        let entries = dates.sorted().map { LockinEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

extension WidgetSnapshot {
    static let preview: WidgetSnapshot = {
        let now = Date()
        return WidgetSnapshot(
            day: Calendar.current.startOfDay(for: now), routinesDone: 3, routinesTotal: 5,
            placeName: "London", prayers: [PrayerTime(name: "Asr", date: now.addingTimeInterval(3600))],
            sessionStart: nil, sessionEnd: nil, groupName: nil, focusMinutesToday: 50, streakDays: 4,
            routines: [
                RoutineInfo(id: UUID(), name: "Salah", symbol: "moon.stars", slots: [
                    .init(id: UUID(), name: "Fajr", time: now.addingTimeInterval(-6 * 3600)),
                    .init(id: UUID(), name: "Dhuhr", time: now.addingTimeInterval(-2 * 3600)),
                    .init(id: UUID(), name: "Asr", time: now.addingTimeInterval(3600)),
                    .init(id: UUID(), name: "Maghrib", time: now.addingTimeInterval(3 * 3600)),
                    .init(id: UUID(), name: "Isha", time: now.addingTimeInterval(5 * 3600)),
                ]),
            ]
        )
    }()
}
