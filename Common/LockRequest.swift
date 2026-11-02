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
