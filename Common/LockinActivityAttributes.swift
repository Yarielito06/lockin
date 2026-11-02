import ActivityKit
import Foundation

/// The Live Activity shown on the lock screen and in the Dynamic Island while locked in.
struct LockinActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var groupName: String?
        /// Free time: count up from `startDate` instead of down to `endDate`.
        var openEnded: Bool? = nil
    }
}
