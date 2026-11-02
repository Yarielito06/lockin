import Combine
import Foundation
import WidgetKit

/// Keeps the widget's snapshot in the App Group up to date: whenever routines, the running
/// session or history change, it writes a fresh `WidgetSnapshot` and asks WidgetKit to reload.
@MainActor
final class WidgetPublisher: ObservableObject {
    private let routines: RoutineStore
    private let blocking: BlockingManager
    private let history: HistoryStore
    private var lastPublished: WidgetSnapshot?
    private var cancellables = Set<AnyCancellable>()

    init(routines: RoutineStore, blocking: BlockingManager, history: HistoryStore) {
        self.routines = routines
        self.blocking = blocking
        self.history = history

        // objectWillChange fires *before* the change, so wait a beat and read the new state.
        Publishers.Merge3(routines.objectWillChange, blocking.objectWillChange, history.objectWillChange)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.publish() }
            .store(in: &cancellables)

        publish()
    }

    func publish() {
        let snapshot = makeSnapshot(now: .now)
        guard snapshot != lastPublished else { return }
        lastPublished = snapshot
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func makeSnapshot(now: Date) -> WidgetSnapshot {
        let calendar = Calendar.current
        let progress = routines.todayProgress
        let session = blocking.activeSession

        var placeName: String?
        var prayers: [WidgetSnapshot.PrayerTime] = []
        if let settings = routines.routines.compactMap(\.prayerSettings).first {
            placeName = settings.placeName
            let today = PrayerCalculator.times(for: settings, on: now)
            prayers = PrayerName.allCases.compactMap { name in
                today[name].map { WidgetSnapshot.PrayerTime(name: name.title, date: $0) }
            }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               let fajr = PrayerCalculator.times(for: settings, on: tomorrow)[.fajr] {
                prayers.append(WidgetSnapshot.PrayerTime(name: PrayerName.fajr.title, date: fajr))
            }
        }

        return WidgetSnapshot(
            day: calendar.startOfDay(for: now),
            routinesDone: progress.done,
            routinesTotal: progress.total,
            placeName: placeName,
            prayers: prayers,
            sessionStart: session?.startDate,
            sessionEnd: session?.endDate,
            groupName: session?.groupName,
            sessionOpenEnded: session?.isOpenEnded,
            focusMinutesToday: history.todayMinutes,
            streakDays: history.streakDays,
            routines: routines.routines.map { routine in
                let times = routine.prayerSettings.map { PrayerCalculator.times(for: $0, on: now) } ?? [:]
                return WidgetSnapshot.RoutineInfo(
                    id: routine.id,
                    name: routine.name,
                    symbol: routine.symbol,
                    slots: routine.slots.map { slot in
                        .init(
                            id: slot.id,
                            name: slot.name,
                            time: slot.prayer.flatMap { times[$0] },
                            detail: slot.detailText,
                            schedule: slot.effectiveSchedule
                        )
                    }
                )
            }
        )
    }
}
