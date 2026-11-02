import DeviceActivity
import Foundation
import os

/// Runs in the background, separately from the app. Lifts the shields when a focus
/// session's schedule ends — even if FocusTogether itself has been killed.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "FocusTogether", category: "DeviceActivityMonitor")

    /// The callback can arrive slightly before the scheduled end. A *new* session is always
    /// at least 15 minutes long, so this tolerance can't mistake one for the old session.
    private let endTolerance: TimeInterval = 60

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .focusSession,
              let session = SharedStore.loadSession(),
              !session.isFinished(at: .now)
        else { return }

        // The app applies shields itself when a session starts; re-applying here is a safety net.
        ShieldController.apply(SharedStore.loadSelection())
        logger.info("Focus interval started; shields applied")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .focusSession else { return }

        // `stopMonitoring` from an early "Give up" can end the old interval after a new session
        // has started. Only clear when the stored session (if any) is actually over.
        if let session = SharedStore.loadSession(),
           session.endDate.timeIntervalSinceNow > endTolerance {
            logger.info("Interval ended but a newer session is running; keeping shields")
            return
        }

        ShieldController.clear()
        logger.info("Focus interval ended; shields cleared")
    }
}
