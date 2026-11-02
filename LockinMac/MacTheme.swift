import AppKit
import SwiftUI

/// The same design tokens the iPhone app uses, so the shared data code compiles unchanged.
enum Theme {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.18)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let track = Color.primary.opacity(0.08)
    static let cornerRadius: CGFloat = 22
    static let gutter: CGFloat = 20
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75)
}

enum Haptics {
    static func tap() { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default) }
    static func select() { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default) }
    static func success() { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default) }
}

extension Int {
    /// 45 → "45m", 125 → "2h 5m".
    var minutesLabel: String {
        guard self >= 60 else { return "\(self)m" }
        let hours = self / 60, minutes = self % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}

// MARK: - Glass

/// Frosted glass over whatever is behind the window: liquid glass on macOS 26, material before that.
struct GlassCard: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 24

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let padded = content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
        if #available(macOS 26.0, *) {
            padded.glassEffect(.regular, in: shape)
        } else {
            padded.background { shape.fill(.ultraThinMaterial).overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1)) }
        }
    }
}

extension View {
    func glassCard(padding: CGFloat = 18, radius: CGFloat = 24) -> some View {
        modifier(GlassCard(padding: padding, radius: radius))
    }
}

/// Makes the window itself see-through: your desktop shows behind the sidebar and cards.
struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
