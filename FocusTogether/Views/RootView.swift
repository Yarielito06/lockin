import FamilyControls
import SwiftUI

/// Shows onboarding until Screen Time access is granted, then the main tabs.
/// The celebration is presented over everything when a session finishes.
struct RootView: View {
    @EnvironmentObject private var blocking: BlockingManager
    @EnvironmentObject private var routines: RoutineStore
    @EnvironmentObject private var widgets: WidgetPublisher
    @EnvironmentObject private var planner: PlannerStore
    @Environment(\.scenePhase) private var scenePhase

    private var isAuthorized: Bool {
        #if DEBUG
        // Screen Time can't be authorized in the Simulator; this flag lets the UI be previewed there.
        if ProcessInfo.processInfo.arguments.contains("-previewUI") { return true }
        #endif
        return blocking.authorizationStatus == .approved
    }

    var body: some View {
        ZStack {
            if isAuthorized {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isAuthorized)
        .fullScreenCover(item: completedSession) { session in
            CelebrationView(session: session)
        }
        #if DEBUG
        .task {
            // Simulator preview of the Live Activity (sessions can't start without Screen Time).
            if ProcessInfo.processInfo.arguments.contains("-previewLiveActivity") {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                LiveActivityController.start(FocusSession(startDate: .now, durationMinutes: 25, groupName: "Library crew"))
            }
        }
        #endif
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                blocking.refresh()
                routines.reloadSharedCompletions()
                routines.refreshReminders()
                // Keeps the week of morning nudges rolling forward.
                planner.scheduleReminders()
                widgets.publish()
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { blocking.errorMessage != nil },
                set: { if !$0 { blocking.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(blocking.errorMessage ?? "") }
        )
    }

    private var completedSession: Binding<FocusSession?> {
        Binding(
            get: { blocking.completedSession },
            set: { if $0 == nil { blocking.dismissCelebration() } }
        )
    }
}
