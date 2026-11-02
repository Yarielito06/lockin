import FamilyControls
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// A named store, so the app and the monitor extension write to the same shields.
    static let focusSession = Self("focusSession")
}

/// Applies and removes the shields for a focus session. Used by both the app
/// (when a session starts or ends early) and the monitor extension (when the schedule ends).
enum ShieldController {
    private static var store: ManagedSettingsStore { ManagedSettingsStore(named: .focusSession) }

    static func apply(_ selection: FamilyActivitySelection) {
        let store = store
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            store.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
    }

    static func clear() {
        store.clearAllSettings()
    }
}
