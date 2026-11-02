import AppIntents
import DeviceActivity
import FamilyControls
import Foundation
import UserNotifications
import WidgetKit

/// Starts a lock-in from a widget or Control Center button, entirely inside the widget — Lockin
/// never opens. It does what the app does: schedules the end first (so the block always lifts),
/// then applies the shields. Live Activity and history are picked up when Lockin next opens.
struct WidgetLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Lock in"
    static var description = IntentDescription("Starts a Lockin session.")
    static var openAppWhenRun = false

    /// "free" or a number of minutes.
    @Parameter(title: "Mode")
    var mode: String

    init() { mode = "free" }

    init(mode: String) { self.mode = mode }

    func perform() async throws -> some IntentResult {
        // Already locked in: nothing to do.
        if let running = SharedStore.loadSession(), !running.isFinished(at: .now) { return .result() }

        let selection = SharedStore.loadSelection()
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else {
            LockRequest.post(mode)   // No apps chosen yet: Lockin will take you to the Lock tab next time.
            return .result()
        }

        let session: FocusSession
        if mode == "free" {
            session = FocusSession(openEndedFrom: .now)
        } else if let minutes = Int(mode), minutes >= 15 {
            session = FocusSession(startDate: .now, durationMinutes: minutes)
        } else {
            return .result()
        }

        // Schedule first: if that fails, don't block anything that could never lift by itself.
        do {
            try schedule(session)
        } catch {
            LockRequest.post(mode)
            return .result()
        }
        ShieldController.apply(selection)
        SharedStore.saveSession(session)

        if !session.isOpenEnded { await notifyAtEnd(session) }

        // Show the locked state on the widget straight away.
        var snapshot = WidgetSnapshot.load()
        snapshot.sessionStart = session.startDate
        snapshot.sessionEnd = session.endDate
        snapshot.sessionOpenEnded = session.isOpenEnded
        snapshot.groupName = nil
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    private func schedule(_ session: FocusSession) throws {
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: session.startDate),
            intervalEnd: calendar.dateComponents(components, from: session.endDate),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.focusSession])
        try center.startMonitoring(.focusSession, during: schedule)
    }

    private func notifyAtEnd(_ session: FocusSession) async {
        let content = UNMutableNotificationContent()
        content.title = "Well done! 🎉"
        content.body = "You locked in for \(session.durationMinutes) minutes. Your apps are unlocked."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "lockin.session.end",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, session.remaining(at: .now)), repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
