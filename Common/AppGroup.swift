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

    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard
}
