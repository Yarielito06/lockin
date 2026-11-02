import SwiftUI

@main
struct LockinMacApp: App {
    @StateObject private var history: HistoryStore
    @StateObject private var routines: RoutineStore
    @StateObject private var planner: PlannerStore
    @StateObject private var focus: MacFocus
    private let island: IslandController

    init() {
        // Pull anything your iPhone has already put in iCloud before the stores load.
        CloudSync.start()
        let history = HistoryStore()
        let focus = MacFocus(history: history)
        _history = StateObject(wrappedValue: history)
        _routines = StateObject(wrappedValue: RoutineStore())
        _planner = StateObject(wrappedValue: PlannerStore())
        _focus = StateObject(wrappedValue: focus)
        island = IslandController(focus: focus)
    }

    var body: some Scene {
        WindowGroup("Lockin", id: "main") {
            MacRootView()
                .environmentObject(history)
                .environmentObject(routines)
                .environmentObject(planner)
                .environmentObject(focus)
                .frame(minWidth: 1020, minHeight: 700)
                .background(WindowGlass().ignoresSafeArea())
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 800)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(focus)
        } label: {
            MenuBarLabel().environmentObject(focus)
        }
        .menuBarExtraStyle(.window)
    }
}
