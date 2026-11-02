import SwiftUI
import WidgetKit

struct LockinWidgetView: View {
    let entry: LockinEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var isLocked: Bool { snapshot.isLocked(at: entry.date) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium.widgetBackground()
        default: small.widgetBackground()
        }
    }

    // MARK: Home screen

    private var small: some View {
        Group {
            if isLocked {
                VStack(alignment: .leading, spacing: 6) {
                    lockedLabel
                    Spacer(minLength: 0)
                    countdown.font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text(snapshot.groupName.map { "with \($0)" } ?? "left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ring(size: 44, lineWidth: 6)
                        Spacer()
                        if snapshot.streakDays > 0 { streak }
                    }
                    Spacer(minLength: 0)
                    Text("\(doneToday) of \(totalToday)")
                        .font(.title3.bold().monospacedDigit())
                    nextPrayerLine.font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            if isLocked {
                VStack(alignment: .leading, spacing: 6) {
                    lockedLabel
                    Spacer(minLength: 0)
                    countdown.font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text(snapshot.groupName.map { "with \($0)" } ?? "Stay focused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView(timerInterval: sessionInterval, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular)
                    .tint(Brand.orange)
                    .frame(width: 56, height: 56)
            } else {
                ring(size: 64, lineWidth: 8)
                    .overlay(
                        Text("\(doneToday)/\(totalToday)")
                            .font(.subheadline.bold().monospacedDigit())
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today")
                        .font(.headline)
                    nextPrayerLine.font(.subheadline)
                    HStack(spacing: 12) {
                        Label("\(snapshot.focusMinutesToday)m", systemImage: "lock.fill")
                        if snapshot.streakDays > 0 { streak }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Lock screen

    private var circular: some View {
        Group {
            if isLocked {
                ProgressView(timerInterval: sessionInterval, countsDown: true) {
                    Image(systemName: "lock.fill")
                } currentValueLabel: {
                    Image(systemName: "lock.fill")
                }
                .progressViewStyle(.circular)
            } else {
                Gauge(value: Double(doneToday), in: 0...Double(max(1, totalToday))) {
                    Image(systemName: "checkmark")
                } currentValueLabel: {
                    Text("\(doneToday)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        }
        .widgetAccentable()
        .accessoryBackground()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isLocked {
                Label("Locked in", systemImage: "lock.fill")
                    .font(.headline)
                    .widgetAccentable()
                countdown.font(.title3.monospacedDigit())
            } else {
                if let next = snapshot.nextPrayer(after: entry.date) {
                    Text("\(next.name) \(next.date.formatted(date: .omitted, time: .shortened))")
                        .font(.headline)
                        .widgetAccentable()
                } else {
                    Text("Lockin").font(.headline).widgetAccentable()
                }
                Text("\(doneToday) of \(totalToday) done today")
                    .font(.caption)
                if snapshot.streakDays > 0 {
                    Text("🔥 \(snapshot.streakDays)-day streak").font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessoryBackground()
    }

    @ViewBuilder
    private var inline: some View {
        if isLocked, let end = snapshot.sessionEnd {
            Text("🔒 Locked in · \((snapshot.sessionOpenEnded == true ? snapshot.sessionStart : nil) ?? end, style: .timer)")
        } else if let next = snapshot.nextPrayer(after: entry.date) {
            Text("\(next.name) at \(next.date.formatted(date: .omitted, time: .shortened)) · \(doneToday)/\(totalToday)")
        } else {
            Text("\(doneToday) of \(totalToday) done today")
        }
    }

    // MARK: Pieces

    private var totalToday: Int {
        entry.isPreview ? snapshot.routinesTotal : snapshot.routinesTotal(on: entry.date)
    }

    private var doneToday: Int {
        entry.isPreview ? snapshot.routinesDone : snapshot.routinesDone(on: entry.date)
    }

    private var progress: Double {
        totalToday == 0 ? 0 : Double(doneToday) / Double(totalToday)
    }

    private var sessionInterval: ClosedRange<Date> {
        let start = snapshot.sessionStart ?? entry.date
        let end = max(snapshot.sessionEnd ?? entry.date, start.addingTimeInterval(1))
        return start...end
    }

    private var lockedLabel: some View {
        Label("Locked in", systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.orange)
    }

    /// Counts down live without needing new timeline entries.
    @ViewBuilder
    private var countdown: some View {
        if snapshot.sessionOpenEnded == true, let start = snapshot.sessionStart {
            // Free time counts up from the start.
            Text(start, style: .timer)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else if let end = snapshot.sessionEnd {
            Text(end, style: .timer)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Brand.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    private var streak: some View {
        Label("\(snapshot.streakDays)", systemImage: "flame.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(Brand.orange)
    }

    @ViewBuilder
    private var nextPrayerLine: some View {
        if let next = snapshot.nextPrayer(after: entry.date) {
            Text("\(next.name) at \(next.date.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text(totalToday == 0 ? "Add a routine in Lockin" : "done today")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private extension View {
    /// iOS 17 requires `containerBackground`; iOS 16 widgets draw their own padded background.
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color(.systemBackground) }
        } else {
            padding().background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    func accessoryBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { AccessoryWidgetBackground() }
        } else {
            self
        }
    }
}

/// Lockin's accent, set directly: inside widgets `Color.accentColor` follows the system tint.
enum Brand {
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.18)
}
