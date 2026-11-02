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
    private let social: SocialStore
    private let planner: PlannerStore
    private var lastPublished: WidgetSnapshot?
    private var cancellables = Set<AnyCancellable>()

    init(routines: RoutineStore, blocking: BlockingManager, history: HistoryStore, social: SocialStore, planner: PlannerStore) {
        self.routines = routines
        self.blocking = blocking
        self.history = history
        self.social = social
        self.planner = planner

        // objectWillChange fires *before* the change, so wait a beat and read the new state.
        Publishers.MergeMany(routines.objectWillChange.eraseToAnyPublisher(), blocking.objectWillChange.eraseToAnyPublisher(), history.objectWillChange.eraseToAnyPublisher(), social.objectWillChange.eraseToAnyPublisher(), planner.objectWillChange.eraseToAnyPublisher())
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
            },
            friendsLocked: social.friendsFocusing(at: now).filter { !$0.isSample }.prefix(6).compactMap { friend in
                friend.focusingUntil.map { .init(id: friend.id, name: friend.name, until: $0, since: friend.focusingSince, isOpen: friend.isFocusOpen) }
            },
            goals: planner.activeGoals.prefix(3).map { .init(id: $0.id, title: $0.title, symbol: $0.symbol, targetDate: $0.targetDate, createdAt: $0.createdAt) },
            plannedItems: planner.upcoming(limit: 4).filter { !$0.isGoal }.map { .init(id: $0.id, title: $0.title, symbol: $0.symbol, date: $0.date) }
        )
    }
}
