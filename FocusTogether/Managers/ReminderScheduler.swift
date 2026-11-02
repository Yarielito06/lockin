import Foundation
import UserNotifications

/// Local notifications for routines (prayer times, daily reminders) and the end of a focus session.
enum ReminderScheduler {
    static let sessionEndID = "lockin.session.end"
    private static let routinePrefix = "lockin.routine."
    /// iOS keeps at most 64 pending notifications per app; leave room for the session one.
    private static let maxRoutineRequests = 44
    private static let planPrefix = "lockin.plan."
    private static let maxPlanRequests = 16
    private static let prayerDaysAhead = 7

    private static var center: UNUserNotificationCenter { .current() }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    // MARK: Routines

    /// Replaces all routine reminders. Prayer reminders cover the next week, so call this
    /// whenever routines change and when the app comes to the foreground.
    static func reschedule(_ routines: [Routine], isDone: (RoutineSlot, Date) -> Bool) {
        let requests = makeRequests(for: routines, now: .now, isDone: isDone)
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(routinePrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            requests.forEach { center.add($0) }
            #if DEBUG
            if let first = requests.first {
                print("[Reminders] scheduled \(requests.count); next: \(first.content.title) — \(first.content.body) at \(nextFire(first))")
            } else {
                print("[Reminders] scheduled 0")
            }
            #endif
        }
    }

    private static func makeRequests(for routines: [Routine], now: Date, isDone: (RoutineSlot, Date) -> Bool) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        var requests: [UNNotificationRequest] = []

        for routine in routines {
            if let minutes = routine.prayerReminderMinutes, let settings = routine.prayerSettings {
                for offset in 0..<prayerDaysAhead {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                    let times = PrayerCalculator.times(for: settings, on: day)
                    for slot in routine.slots {
                        guard let prayer = slot.prayer, let time = times[prayer] else { continue }
                        let fireDate = time.addingTimeInterval(-TimeInterval(minutes * 60))
                        guard fireDate > now else { continue }
                        // Already prayed today — no need to remind.
                        if offset == 0, isDone(slot, now) { continue }

                        let content = UNMutableNotificationContent()
                        content.title = minutes == 0 ? "Time for \(prayer.title)" : "\(prayer.title) in \(minutes) min"
                        content.body = "\(settings.placeName) · \(time.formatted(date: .omitted, time: .shortened))"
                        content.sound = .default

                        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                        let dayStamp = calendar.dateComponents([.year, .month, .day], from: day)
                        let id = "\(routinePrefix)\(routine.id).\(dayStamp.year ?? 0)-\(dayStamp.month ?? 0)-\(dayStamp.day ?? 0).\(prayer.rawValue)"
                        requests.append(UNNotificationRequest(
                            identifier: id,
                            content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        ))
                    }
                }
            }

            if let time = routine.reminderTime {
                let content = UNMutableNotificationContent()
                content.title = routine.name
                content.body = routine.slots.map(\.name).joined(separator: " · ")
                content.sound = .default
                requests.append(UNNotificationRequest(
                    identifier: "\(routinePrefix)\(routine.id).daily",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: DateComponents(hour: time.hour, minute: time.minute),
                        repeats: true
                    )
                ))
            }
        }

        // Soonest first, so the cap drops the far-off ones.
        return Array(requests.sorted { nextFire($0) < nextFire($1) }.prefix(maxRoutineRequests))
    }

    private static func nextFire(_ request: UNNotificationRequest) -> Date {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    // MARK: Goals, deadlines and events

    /// Replaces all planner reminders: on the day, the evening before a deadline or exam, and a week,
    /// a day and the morning of a goal's day.
    static func reschedulePlanner(items: [PlanItem], goals: [Goal]) {
        let now = Date()
        let calendar = Calendar.current
        var requests: [UNNotificationRequest] = []

        func add(_ id: String, title: String, body: String, at date: Date) {
            guard date > now else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            requests.append(UNNotificationRequest(
                identifier: planPrefix + id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }

        for item in items where !item.isDone {
            add("\(item.id).day", title: "\(item.kind.title): \(item.title)", body: item.hasTime ? "Today at \(item.date.formatted(date: .omitted, time: .shortened))" : "Due today", at: item.fireDate)
            if item.kind == .deadline || item.kind == .exam,
               let eve = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: item.date)),
               let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: eve) {
                add("\(item.id).eve", title: "Tomorrow: \(item.title)", body: "Your \(item.kind.title.lowercased()) is tomorrow. Lock in tonight?", at: evening)
            }
        }
        for goal in goals {
            let day = calendar.startOfDay(for: goal.targetDate)
            for (offset, text) in [(-7, "A week to go"), (-1, "Tomorrow is the day")] {
                if let date = calendar.date(byAdding: .day, value: offset, to: day),
                   let nine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) {
                    add("\(goal.id).\(offset)", title: "\(text): \(goal.title)", body: "\(goal.title) is on \(goal.targetDate.formatted(.dateTime.weekday(.wide).day().month(.wide))).", at: nine)
                }
            }
            if let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) {
                add("\(goal.id).day", title: "Today is the day: \(goal.title)", body: "You've got this.", at: morning)
            }
        }

        let capped = Array(requests.sorted { nextFire($0) < nextFire($1) }.prefix(maxPlanRequests))
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(planPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            capped.forEach { center.add($0) }
        }
    }

    // MARK: Focus session

    static func scheduleSessionEnd(_ session: FocusSession) {
        let content = UNMutableNotificationContent()
        content.title = "Well done! 🎉"
        content.body = "You locked in for \(session.durationMinutes) minutes. Your apps are unlocked."
        content.sound = .default
        let interval = max(1, session.remaining(at: .now))
        center.add(UNNotificationRequest(
            identifier: sessionEndID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        ))
    }

    static func cancelSessionEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [sessionEndID])
    }
}

/// Shows routine reminders as banners even while Lockin is open. The session-end one is
/// skipped in the foreground because the celebration screen already covers it.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == ReminderScheduler.sessionEndID {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound, .list])
        }
    }
}
