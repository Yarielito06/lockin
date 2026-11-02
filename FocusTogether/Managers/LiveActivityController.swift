import ActivityKit
import Foundation

/// Starts and ends the "Locked in" Live Activity. The countdown itself is rendered by the
/// system from the end date, so nothing needs updating while the session runs.
enum LiveActivityController {
    private typealias LockinActivity = Activity<LockinActivityAttributes>

    static func start(_ session: FocusSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = LockinActivityAttributes.ContentState(
            startDate: session.startDate,
            endDate: session.endDate,
            groupName: session.groupName,
            openEnded: session.isOpenEnded
        )
        Task {
            await endAll()
            if #available(iOS 16.2, *) {
                // Marked stale at the end time, so the activity shows "complete" even if Lockin was killed.
                _ = try? LockinActivity.request(
                    attributes: LockinActivityAttributes(),
                    content: ActivityContent(state: state, staleDate: session.isOpenEnded ? nil : session.endDate),
                    pushType: nil
                )
            } else {
                _ = try? LockinActivity.request(attributes: LockinActivityAttributes(), contentState: state, pushType: nil)
            }
        }
    }

    static func end() {
        Task { await endAll() }
    }

    private static func endAll() async {
        for activity in LockinActivity.activities {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
