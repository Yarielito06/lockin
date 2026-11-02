import SwiftUI
import UserNotifications

@main
struct LockinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var history: HistoryStore
    @StateObject private var blocking: BlockingManager
    @StateObject private var routines: RoutineStore
    @StateObject private var social: SocialStore
    @StateObject private var widgets: WidgetPublisher
    @StateObject private var moments = MomentsStore()
    @StateObject private var avatars = AvatarStore()
    @StateObject private var cardBackgrounds = CardBackgroundStore()
    @StateObject private var planner: PlannerStore

    init() {
        CloudSync.start()
        let history = HistoryStore()
        let blocking = BlockingManager(history: history)
        let routines = RoutineStore()
        let social = SocialStore()
        social.observe(blocking: blocking, history: history)
        let planner = PlannerStore()
        _history = StateObject(wrappedValue: history)
        _blocking = StateObject(wrappedValue: blocking)
        _routines = StateObject(wrappedValue: routines)
        _social = StateObject(wrappedValue: social)
        _planner = StateObject(wrappedValue: planner)
        let widgetPublisher = WidgetPublisher(routines: routines, blocking: blocking, history: history, social: social, planner: planner)
        _widgets = StateObject(wrappedValue: widgetPublisher)
        // Lets a shortcut start a lock-in while the app stays in the background.
        LockRequestHandler.handler = { mode in
            await MainActor.run {
                blocking.startFromRequest(mode)
                widgetPublisher.publish()
            }
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(blocking)
                .environmentObject(history)
                .environmentObject(routines)
                .environmentObject(social)
                .environmentObject(widgets)
                .environmentObject(moments)
                .environmentObject(avatars)
                .environmentObject(cardBackgrounds)
                .environmentObject(planner)
        }
    }
}
