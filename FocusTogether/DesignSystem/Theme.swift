import SwiftUI

/// Lockin's design tokens: monochrome ink on quiet surfaces, with a single warm accent.
/// Change the accent in Assets.xcassets › AccentColor.
enum Theme {
    static let accent = Color.accentColor
    static let background = Color(.systemBackground)
    static let surface = Color(.secondarySystemBackground)
    static let track = Color.primary.opacity(0.08)

    static let cornerRadius: CGFloat = 22
    static let gutter: CGFloat = 20

    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75)
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

extension Int {
    /// 45 → "45m", 125 → "2h 5m".
    var minutesLabel: String {
        guard self >= 60 else { return "\(self)m" }
        let hours = self / 60, minutes = self % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
