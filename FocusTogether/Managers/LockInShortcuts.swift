import AppIntents

/// Set by the app at launch so shortcuts can start a lock-in inside the app's own process.
enum LockRequestHandler {
    static var handler: ((String) async -> Void)?
}

/// "Lock in" for Siri, the Shortcuts app, the Action Button, Back Tap and the Lock Screen.
/// It runs in the background — Lockin doesn't open.
struct StartLockInIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a lock-in"
    static var description = IntentDescription("Blocks your chosen apps until you stop.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        LockLog.add("shortcut intent ran")
        if let handler = LockRequestHandler.handler {
            await handler("free")
            return .result(dialog: "Locked in. Stay with it.")
        }
        LockRequest.post("free")
        return .result(dialog: "Open Lockin once to finish starting.")
    }
}

struct LockinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLockInIntent(),
            phrases: ["Lock in with \(.applicationName)", "Start \(.applicationName)", "Lock my phone with \(.applicationName)"],
            shortTitle: "Lock in",
            systemImageName: "lock.fill"
        )
    }
}
