import SwiftUI


/// Makes sure a window is on screen at launch and when you click the Dock icon.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    static var focus: MacFocus?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let focus = Self.focus { statusItem = StatusItemController(focus: focus) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Self.ensureWindow() }
        return true
    }

    private static func hasWindow() -> Bool {
        NSApp.windows.contains { $0.isVisible && $0.canBecomeMain && $0.frame.width > 300 }
    }

    /// Brings the main window forward, asking macOS to "reopen" the app if it was closed.
    static func ensureWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.frame.width > 300 }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }
}

@main
struct LockinMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
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
        MacAppDelegate.focus = focus
    }

    var body: some Scene {
        Window("Lockin", id: "main") {
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

    }
}
