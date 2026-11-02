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

    private var small: some View {
        Group {
            if isLocked {
                lockedSmall
            } else {
                Link(destination: LockRequest.url("free")) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            glowingLock(size: 46)
                            Spacer()
                            if snapshot.streakDays > 0 {
                                Label("\(snapshot.streakDays)", systemImage: "flame.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(StartPalette.amber)
                            }
                        }
                        Spacer(minLength: 0)
                        Text("Lock in")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(needsApps ? "Choose apps first" : "Free time · tap to start")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var medium: some View {
        Group {
            if isLocked {
                lockedMedium
            } else {
                HStack(spacing: 14) {
                    Link(destination: LockRequest.url("free")) {
                        VStack(alignment: .leading, spacing: 0) {
                            glowingLock(size: 46)
                            Spacer(minLength: 0)
                            Text("Lock in")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(needsApps ? "Choose apps first" : "\(snapshot.focusMinutesToday)m today")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            pill("Free", symbol: "infinity", mode: "free", highlighted: true)
                            pill("25", mode: "25")
                        }
                        HStack(spacing: 8) {
                            pill("50", mode: "50")
                            pill("90", mode: "90")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func pill(_ title: String, symbol: String? = nil, mode: String, highlighted: Bool = false) -> some View {
        Link(destination: LockRequest.url(mode)) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded))
                if symbol == nil { Text("min").font(.system(size: 10, weight: .semibold)).opacity(0.7) }
            }
            .foregroundStyle(highlighted ? Color.black : Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                highlighted
                    ? AnyShapeStyle(LinearGradient(colors: [StartPalette.amber, StartPalette.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    private func glowingLock(size: CGFloat) -> some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [StartPalette.amber, StartPalette.orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .shadow(color: StartPalette.orange.opacity(0.55), radius: 10)
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
            glowingLock(size: 64)
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
                Image(systemName: "lock.open.fill").font(.system(size: 22))
                    .widgetURL(LockRequest.url("free"))
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
                Label("Lock in", systemImage: "lock.open.fill").font(.headline).widgetAccentable()
                Text(needsApps ? "Choose apps first" : "Tap to start free time").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(isLocked ? nil : LockRequest.url("free"))
        .accessoryBackground()
    }
}

private extension View {
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
            ControlWidgetButton(action: LockInIntent(mode: "free")) {
                Label("Lock in", systemImage: "lock.fill")
            }
        }
        .displayName("Lock in")
        .description("Start a free-time lock-in.")
    }
}
