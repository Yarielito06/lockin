import Foundation

/// The App Group shared by the app and its extensions.
///
/// The identifier is read from each bundle's Info.plist (`FTAppGroupIdentifier`), which is
/// filled in from `BUNDLE_ID_PREFIX` in Config/Signing.xcconfig — so there is one place to change it.
enum AppGroup {
    static let identifier: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "FTAppGroupIdentifier") as? String
        assert(value?.isEmpty == false, "FTAppGroupIdentifier is missing from Info.plist")
        return value ?? "group.com.example.FocusTogether"
    }()

    /// Small profile photos for widgets, which can't reach the network or the app's own stores.
    static func avatarURL(for id: UUID) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appendingPathComponent("avatars", isDirectory: true)
            .appendingPathComponent("\(id.uuidString.lowercased()).jpg")
    }

    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard
}
