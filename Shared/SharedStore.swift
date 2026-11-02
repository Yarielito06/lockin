import Foundation
import FamilyControls

/// Reads and writes state that the app and the DeviceActivityMonitor extension share
/// through App Group UserDefaults.
enum SharedStore {
    private enum Key {
        static let selection = "ft.activitySelection"
        static let activeSession = "ft.activeSession"
    }

    private static var defaults: UserDefaults { AppGroup.defaults }

    // MARK: Selection

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: Key.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Key.selection)
    }

    // MARK: Active session

    static func loadSession() -> FocusSession? {
        guard let data = defaults.data(forKey: Key.activeSession) else { return nil }
        return try? JSONDecoder().decode(FocusSession.self, from: data)
    }

    static func saveSession(_ session: FocusSession?) {
        guard let session, let data = try? JSONEncoder().encode(session) else {
            defaults.removeObject(forKey: Key.activeSession)
            return
        }
        defaults.set(data, forKey: Key.activeSession)
    }
}
