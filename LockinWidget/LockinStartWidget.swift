import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Lock in widget

/// One tap from the Home Screen or Lock Screen to a lock-in, before you can open anything else.
struct LockinStartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockinStartWidget", provider: LockinProvider()) { entry in
            StartWidgetView(entry: entry)
        }
        .configurationDisplayName("Lock in")
        .description("Start a lock-in with one tap, so you never reach for social media first.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private enum StartPalette {
    static let top = Color(red: 0.07, green: 0.06, blue: 0.07)
    static let bottom = Color(red: 0.16, green: 0.08, blue: 0.05)
    static let orange = Color(red: 1.0, green: 0.46, blue: 0.20)
    static let amber = Color(red: 1.0, green: 0.64, blue: 0.30)
}

/// A button that starts a lock-in right where you are. On iOS 17+ it runs without opening Lockin.
private struct LockButton<Content: View>: View {
    let mode: String
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 17.0, *) {
            // The whole area counts as the button, not just the drawn pixels.
            Button(intent: WidgetLockIntent(mode: mode)) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: LockRequest.url(mode)) { content }
        }
    }
}

private struct StartWidgetView: View {
    let entry: LockinEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var isLocked: Bool { snapshot.isLocked(at: entry.date) }
    private var needsApps: Bool { snapshot.hasBlockedApps == false }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium.startBackground()
        default: small.startBackground()
        }
    }

    // MARK: Home screen

    /// The glowing button: soft rings, an orange disc and the lock.
    private func bigButton(size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(StartPalette.orange.opacity(0.18), lineWidth: 1.5).frame(width: size * 1.45, height: size * 1.45)
            Circle().stroke(StartPalette.orange.opacity(0.30), lineWidth: 1.5).frame(width: size * 1.22, height: size * 1.22)
            Circle()
                .fill(LinearGradient(colors: [StartPalette.amber, StartPalette.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .shadow(color: StartPalette.orange.opacity(0.65), radius: size * 0.22)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
            Image(systemName: "lock.open.fill")
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(.white)
                .replaceTransitionIfAvailable()
        }
    }

    private var small: some View {
        Group {
            if isLocked {
                lockedSmall
            } else {
                LockButton(mode: "free") {
                    VStack(spacing: 10) {
                        bigButton(size: 66)
                        Text(needsApps ? "Choose apps first" : "Lock in")
                            .font(.system(size: needsApps ? 12 : 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(needsApps ? 0.65 : 1))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .invalidatableContentIfAvailable()
                }
            }
        }
    }

    private var medium: some View {
        Group {
            if isLocked {
                lockedMedium
            } else {
                HStack(spacing: 18) {
                    LockButton(mode: "free") {
                        HStack(spacing: 16) {
                            bigButton(size: 62).padding(.leading, 12)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Lock in")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(needsApps ? "Choose apps first" : "Free time")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .invalidatableContentIfAvailable()
                    }

                    HStack(spacing: 8) {
                        ForEach(["25", "50", "90"], id: \.self) { minutes in
                            LockButton(mode: minutes) {
                                VStack(spacing: 0) {
                                    Text(minutes).font(.system(size: 17, weight: .bold, design: .rounded))
                                    Text("min").font(.system(size: 9, weight: .semibold)).opacity(0.6)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 56)
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Already locked

    private var timer: some View {
        Group {
            if snapshot.sessionOpenEnded == true, let start = snapshot.sessionStart {
                Text(start, style: .timer)
            } else if let end = snapshot.sessionEnd {
                Text(end, style: .timer)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var lockedSmall: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Locked in", systemImage: "lock.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(StartPalette.amber)
            Spacer(minLength: 0)
            timer
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(snapshot.sessionOpenEnded == true ? "free time" : (snapshot.groupName.map { "with \($0)" } ?? "left"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var lockedMedium: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Label("Locked in", systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(StartPalette.amber)
                Spacer(minLength: 0)
                timer
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(snapshot.sessionOpenEnded == true ? "free time · stay with it" : "Stay focused — you've got this")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            bigButton(size: 54)
        }
    }

    // MARK: Lock screen

    private var circular: some View {
        Group {
            if isLocked {
                VStack(spacing: 0) {
                    Image(systemName: "lock.fill").font(.system(size: 13))
                    timer.font(.system(size: 11, weight: .semibold))
                }
            } else {
                LockButton(mode: "free") {
                    Image(systemName: "lock.open.fill").font(.system(size: 22))
                }
            }
        }
        .widgetAccentable()
        .accessoryBackground()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isLocked {
                Label("Locked in", systemImage: "lock.fill").font(.headline).widgetAccentable()
                timer.font(.title3.monospacedDigit())
            } else {
                LockButton(mode: "free") {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Lock in", systemImage: "lock.open.fill").font(.headline).widgetAccentable()
                        Text(needsApps ? "Choose apps first" : "Tap to start free time").font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessoryBackground()
    }
}

private extension View {
    /// Morphs the lock icon when it changes (iOS 17+).
    @ViewBuilder
    func replaceTransitionIfAvailable() -> some View {
        if #available(iOS 17.0, *) { contentTransition(.symbolEffect(.replace)) } else { self }
    }

    /// Dims the button while the tap is being handled (iOS 17+).
    @ViewBuilder
    func invalidatableContentIfAvailable() -> some View {
        if #available(iOS 17.0, *) { invalidatableContent() } else { self }
    }

    /// A deep dark card with a warm glow, whatever the system theme.
    @ViewBuilder
    func startBackground() -> some View {
        let background = ZStack {
            LinearGradient(colors: [StartPalette.top, StartPalette.bottom], startPoint: .top, endPoint: .bottom)
            Circle().fill(StartPalette.orange.opacity(0.28)).frame(width: 160, height: 160).blur(radius: 40).offset(x: 70, y: -50)
        }
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { background }
        } else {
            padding().background(background)
        }
    }
}

// MARK: - Control Center / Lock Screen button (iOS 18)

@available(iOS 18.0, *)
struct LockinControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LockinControl") {
            ControlWidgetButton(action: WidgetLockIntent(mode: "free")) {
                Label("Lock in", systemImage: "lock.fill")
            }
        }
        .displayName("Lock in")
        .description("Start a free-time lock-in.")
    }
}
