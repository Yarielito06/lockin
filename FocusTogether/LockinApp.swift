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

    init() {
        let history = HistoryStore()
        let blocking = BlockingManager(history: history)
        let routines = RoutineStore()
        let social = SocialStore()
        social.observe(blocking: blocking, history: history)
        _history = StateObject(wrappedValue: history)
        _blocking = StateObject(wrappedValue: blocking)
        _routines = StateObject(wrappedValue: routines)
        _social = StateObject(wrappedValue: social)
        _widgets = StateObject(wrappedValue: WidgetPublisher(routines: routines, blocking: blocking, history: history))
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
        }
    }
}
