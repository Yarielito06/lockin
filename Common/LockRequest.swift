import AppIntents
import Foundation

/// A request to start a lock-in from outside the app (a widget, the lock screen, Control Center).
/// The widget can't apply the block itself, so it leaves a note here and opens Lockin, which starts at once.
enum LockRequest {
    private static let key = "lockin.pendingLock"

    /// "free" for open-ended, or a number of minutes ("25", "50", "90").
    static func post(_ mode: String) {
        AppGroup.defaults.set(mode, forKey: key)
    }

    static func take() -> String? {
        let value = AppGroup.defaults.string(forKey: key)
        AppGroup.defaults.removeObject(forKey: key)
        return value
    }

    static func url(_ mode: String) -> URL {
        URL(string: "lockin://lock?mode=\(mode)")!
    }
}

/// Set by the app at launch: starts the session in the app's own process.
enum LockRequestHandler {
    static var handler: ((String) async -> Void)?
}

/// Starts a lock-in from a widget or Control Center button without bringing Lockin to the front.
/// As a Live Activity intent it runs inside the app (in the background), where Screen Time can be set up.
@available(iOS 16.4, *)
struct LockInIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Lock in"
    static var description = IntentDescription("Starts a Lockin session.")
    static var openAppWhenRun = false

    /// "free" or a number of minutes.
    @Parameter(title: "Mode")
    var mode: String

    init() { mode = "free" }

    init(mode: String) { self.mode = mode }

    func perform() async throws -> some IntentResult {
        if let handler = LockRequestHandler.handler {
            await handler(mode)
        } else {
            // Not running inside the app: leave a note; Lockin starts the session the next time it opens.
            LockRequest.post(mode)
        }
        return .result()
    }
}
