import AppIntents
import SwiftUI
import WidgetKit

/// Today's routines on the home screen, with circles you tap to tick (iOS 17+).
struct LockinRoutinesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockinRoutines", provider: LockinProvider()) { entry in
            RoutinesWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Tick off prayers and habits right from your Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// Ticks or unticks one item for today. Runs in the widget; the app picks it up when opened.
struct ToggleSlotIntent: AppIntent {
    static var title: LocalizedStringResource = "Tick routine"
    static var description = IntentDescription("Marks a routine item done or not done for today.")

    @Parameter(title: "Slot")
    var slotID: String

    init() {}

    init(slotID: UUID) {
        self.slotID = slotID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: slotID) {
            SharedCompletions.toggle(id, on: .now)
        }
        // iOS only refreshes the tapped widget; the summary widget shows the same count.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

private struct RoutinesWidgetView: View {
    let entry: LockinEntry
    @Environment(\.widgetFamily) private var family

    /// Real ticks, or for the gallery preview, the first few items of each routine ticked.
    private var days: SharedCompletions.Days {
        guard entry.isPreview else { return SharedCompletions.load() }
        let ticked = entry.snapshot.routines.flatMap { $0.slots.prefix(3).map(\.id) }
        return [SharedCompletions.dayKey(for: entry.date): Set(ticked)]
    }

    var body: some View {
        let days = days
        // Routines with something due today come first; a rest-day routine shows last.
        let routines = entry.snapshot.routines
            .sorted { !$0.dueSlots(on: entry.date, in: days).isEmpty && $1.dueSlots(on: entry.date, in: days).isEmpty }
            .prefix(family == .systemLarge ? 3 : 1)

        Group {
            if routines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.title2)
                    Text("Add a routine in Lockin")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 14 : 0) {
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        if index > 0 { Divider() }
                        RoutineRow(routine: routine, days: days, date: entry.date)
                    }
                    if family == .systemLarge { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .routinesBackground()
    }
}

private struct RoutineRow: View {
    let routine: WidgetSnapshot.RoutineInfo
    let days: SharedCompletions.Days
    let date: Date

    var body: some View {
        let due = routine.dueSlots(on: date, in: days)
        let done = due.filter { SharedCompletions.isDone($0.id, on: date, in: days) }.count
        let nextID = due.first { ($0.time ?? .distantPast) > date }?.id

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: routine.symbol)
                    .font(.footnote.weight(.semibold))
                Text(routine.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if !due.isEmpty {
                    Text("\(done)/\(due.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(done == due.count ? Brand.orange : .secondary)
                    MiniRing(progress: Double(done) / Double(due.count))
                        .frame(width: 18, height: 18)
                }
            }

            if due.isEmpty {
                Label("Rest day", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(due.prefix(6), id: \.id) { slot in
                        SlotButton(
                            slot: slot,
                            isDone: SharedCompletions.isDone(slot.id, on: date, in: days),
                            isNext: slot.id == nextID,
                            weekly: weekly(slot)
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func weekly(_ slot: WidgetSnapshot.RoutineInfo.Slot) -> String? {
        guard case .perWeek(let target) = slot.schedule else { return nil }
        return "\(slot.schedule.doneThisWeek(slotID: slot.id, upTo: date, in: days))/\(target) wk"
    }
}

private struct MiniRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Brand.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct SlotButton: View {
    let slot: WidgetSnapshot.RoutineInfo.Slot
    let isDone: Bool
    let isNext: Bool
    let weekly: String?

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleSlotIntent(slotID: slot.id)) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .strokeBorder(ringColor, lineWidth: isNext && !isDone ? 2 : 1.5)
                    .background(Circle().fill(isDone ? Color.primary : .clear))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .opacity(isDone ? 1 : 0)
            }
            .frame(width: 32, height: 32)

            Text(slot.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isDone ? .primary : .secondary)
            if let time = slot.time {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(isNext ? Brand.orange : .secondary)
            } else if let detail = slot.detail {
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            if let weekly {
                Text(weekly)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Brand.orange)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var ringColor: Color {
        if isDone { return .clear }
        return isNext ? Brand.orange : Color.primary.opacity(0.2)
    }
}

private extension View {
    @ViewBuilder
    func routinesBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color(.systemBackground) }
        } else {
            padding().background(Color(.systemBackground))
        }
    }
}
