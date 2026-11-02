import Combine
import DeviceActivity
import FamilyControls
import Foundation

/// Owns Screen Time authorization, the user's app selection, and the lifecycle of a focus session.
@MainActor
final class BlockingManager: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection {
        didSet { SharedStore.saveSelection(selection) }
    }
    @Published private(set) var activeSession: FocusSession?
    @Published private(set) var completedSession: FocusSession?
    @Published var errorMessage: String?

    private let authorizationCenter = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    private let history: HistoryStore
    private var cancellables = Set<AnyCancellable>()

    init(history: HistoryStore) {
        self.history = history
        authorizationStatus = authorizationCenter.authorizationStatus
        selection = SharedStore.loadSelection()
        activeSession = SharedStore.loadSession()

        authorizationCenter.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.authorizationStatus = $0 }
            .store(in: &cancellables)

        refresh()
        // A Live Activity left over from a session that ended while Lockin was closed.
        if activeSession == nil { LiveActivityController.end() }
    }

    /// The iPhone app running on a Mac. Screen Time can't block anything there, so a lock-in
    /// is a focus timer that still counts, ranks up and shows your friends you're locked in.
    static let isOnMac = ProcessInfo.processInfo.isiOSAppOnMac

    var hasSelection: Bool {
        if Self.isOnMac { return true }
        return !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    // MARK: Authorization

    func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Screen Time access wasn't granted. \(error.localizedDescription)"
        }
        authorizationStatus = authorizationCenter.authorizationStatus
    }

    // MARK: Sessions

    /// DeviceActivity can't schedule anything shorter, so a session must have at least this long left.
    static let minimumSessionLength: TimeInterval = 15 * 60

    func startSession(minutes: Int, groupName: String? = nil) {
        start(FocusSession(startDate: .now, durationMinutes: minutes, groupName: groupName))
    }

    /// Starts a session asked for by a widget or button: "free" or a number of minutes.
    /// Does nothing when apps haven't been chosen or a session is already running.
    func startFromRequest(_ mode: String) {
        guard activeSession == nil, hasSelection else { return }
        if mode == "free" {
            startOpenEndedSession()
        } else if let minutes = Int(mode), minutes >= 15 {
            startSession(minutes: minutes)
        }
    }

    /// Free time: locks until you stop it.
    func startOpenEndedSession() {
        start(FocusSession(openEndedFrom: .now))
    }

    /// Joins a group lock-in, finishing at the same time as everyone else.
    func joinSession(until endDate: Date, groupName: String) {
        guard endDate.timeIntervalSinceNow >= Self.minimumSessionLength else {
            errorMessage = "Less than 15 minutes left — too short to join this one."
            return
        }
        start(FocusSession(startDate: .now, endDate: endDate, groupName: groupName))
    }

    private func start(_ session: FocusSession) {
        guard hasSelection, activeSession == nil else { return }

        // Schedule first: if the schedule can't be created, the shields would never lift
        // on their own once the app is killed, so don't apply them at all.
        if !Self.isOnMac {
            do {
                try scheduleMonitoring(for: session)
            } catch {
                errorMessage = "Couldn't schedule the session. \(error.localizedDescription)"
                return
            }
            ShieldController.apply(selection)
        }
        SharedStore.saveSession(session)
        activeSession = session
        LiveActivityController.start(session)

        // Lets the user know it's over even if Lockin was closed.
        Task {
            if await ReminderScheduler.requestPermission(), !session.isOpenEnded {
                ReminderScheduler.scheduleSessionEnd(session)
            }
        }
    }

    /// Ends the session if its time is up. Call when the countdown hits zero and when the app becomes active.
    func refresh(now: Date = .now) {
        // A session started from a widget while the app wasn't looking.
        if activeSession == nil, let stored = SharedStore.loadSession(), !stored.isFinished(at: now) {
            activeSession = stored
            resumeStartedElsewhere(stored)
        }
        guard let session = activeSession else { return }
        if session.isOpenEnded {
            extendOpenEndedIfNeeded(session, now: now)
            return
        }
        guard session.isFinished(at: now) else { return }
        tearDown()
        activeSession = nil
        history.record(session)
        completedSession = session
    }

    /// What the widget can't do itself: the Live Activity, which needs the app.
    private func resumeStartedElsewhere(_ session: FocusSession) {
        if !LiveActivityController.isRunning { LiveActivityController.start(session) }
    }

    /// Stops a free-time session: unlocks, records the time actually spent and celebrates.
    func stopOpenEndedSession(at now: Date = .now) {
        guard let session = activeSession, session.isOpenEnded else { return }
        ReminderScheduler.cancelSessionEnd()
        tearDown()
        activeSession = nil
        let done = session.ended(at: min(now, session.endDate))
        // Under a minute isn't worth recording.
        guard done.durationMinutes >= 1 else { return }
        history.record(done)
        completedSession = done
    }

    /// The monitor interval has a fixed end, so a free-time session pushes its safety cap back
    /// whenever the app is open. If Lockin is never opened, the shields lift at the cap.
    private func extendOpenEndedIfNeeded(_ session: FocusSession, now: Date) {
        if session.endDate <= now {
            // Lockin wasn't opened for a whole cap: the shields are already off, and the time isn't trusted.
            tearDown()
            activeSession = nil
            return
        }
        guard session.endDate.timeIntervalSince(now) < FocusSession.openEndedCap / 2 else { return }
        let extended = FocusSession(id: session.id, openEndedFrom: session.startDate, capUntil: now.addingTimeInterval(FocusSession.openEndedCap))
        do {
            try scheduleMonitoring(for: extended, from: now)
        } catch { return }
        SharedStore.saveSession(extended)
        activeSession = extended
    }

    func giveUp() {
        guard activeSession != nil else { return }
        ReminderScheduler.cancelSessionEnd()
        tearDown()
        activeSession = nil
    }

    func dismissCelebration() {
        completedSession = nil
    }

    // MARK: Private

    private func tearDown() {
        LiveActivityController.end()
        ShieldController.clear()
        activityCenter.stopMonitoring([.focusSession])
        SharedStore.saveSession(nil)
    }

    /// Schedules a one-off DeviceActivity interval for the session; the monitor extension
    /// clears the shields in `intervalDidEnd`, even if this app is no longer running.
    /// DeviceActivity requires an interval of at least 15 minutes.
    private func scheduleMonitoring(for session: FocusSession, from start: Date? = nil) throws {
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start ?? session.startDate),
            intervalEnd: calendar.dateComponents(components, from: session.endDate),
            repeats: false
        )
        activityCenter.stopMonitoring([.focusSession])
        try activityCenter.startMonitoring(.focusSession, during: schedule)
    }
}
