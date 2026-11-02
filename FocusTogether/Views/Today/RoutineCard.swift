import SwiftUI

struct RoutineCard: View {
    let routine: Routine
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// Called with the new streak when the last slot of the day is ticked.
    let onComplete: (Int) -> Void
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let times = routine.prayerSettings.map { PrayerCalculator.times(for: $0, on: now) } ?? [:]
        let next = nextPrayer(in: times, after: now)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: routine.symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(routine.name)
                            .font(.headline)
                        streakBadge(now: now)
                    }
                    if let subtitle = subtitle(next: next, now: now) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(store.doneCount(in: routine))/\(store.dueSlots(in: routine, on: now).count)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .tint(.secondary)
                .accessibilityLabel("Options for \(routine.name)")
            }

            let due = store.dueSlots(in: routine, on: now)
            if due.isEmpty {
                Label("Nothing due today — rest day", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if due.count <= 5 {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(due) { slot in
                        slotToggle(slot, times: times, next: next).frame(maxWidth: .infinity)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(due) { slot in
                            slotToggle(slot, times: times, next: next).frame(width: 66)
                        }
                    }
                }
            }
        }
        .card(padding: 18)
    }

    /// 🔥 and the streak length: orange once today is complete, grey while today is still open.
    @ViewBuilder
    private func streakBadge(now: Date) -> some View {
        let streak = store.streak(for: routine, now: now)
        if streak > 0 {
            let doneToday = store.isComplete(routine, on: now)
            Label("\(streak)", systemImage: "flame.fill")
                .font(.caption.weight(.bold).monospacedDigit())
                .labelStyle(.titleAndIcon)
                .foregroundStyle(doneToday ? Theme.accent : Color.secondary)
                .contentTransition(.numericText())
                .accessibilityLabel(doneToday ? "\(streak)-day streak" : "\(streak)-day streak, finish today to keep it")
        }
    }

    private func subtitle(next: (prayer: PrayerName, time: Date)?, now: Date) -> String? {
        guard let settings = routine.prayerSettings else { return nil }
        if let next {
            return "\(settings.placeName) · \(next.prayer.title) at \(next.time.formatted(date: .omitted, time: .shortened))"
        }
        // After Isha, point at tomorrow's Fajr.
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let fajr = PrayerCalculator.times(for: settings, on: tomorrow)[.fajr]
        else { return settings.placeName }
        return "\(settings.placeName) · Fajr tomorrow at \(fajr.formatted(date: .omitted, time: .shortened))"
    }

    /// The first prayer still to come today.
    private func nextPrayer(in times: [PrayerName: Date], after now: Date) -> (prayer: PrayerName, time: Date)? {
        PrayerName.allCases
            .compactMap { prayer in times[prayer].map { (prayer, $0) } }
            .first { $0.1 > now }
    }

    /// "1/3 this wk" for items done a number of times per week.
    private func weeklyProgress(_ slot: RoutineSlot) -> String? {
        guard case .perWeek(let target) = slot.effectiveSchedule else { return nil }
        return "\(store.doneThisWeek(slot))/\(target) this wk"
    }

    private func slotToggle(_ slot: RoutineSlot, times: [PrayerName: Date], next: (prayer: PrayerName, time: Date)?) -> some View {
        SlotToggle(
            name: slot.name,
            time: slot.prayer.flatMap { times[$0] },
            detail: slot.detailText,
            weekly: weeklyProgress(slot),
            isNext: slot.prayer != nil && slot.prayer == next?.prayer,
            isDone: store.isDone(slot)
        ) {
            let wasComplete = store.isComplete(routine)
            withAnimation(Theme.spring) { store.toggle(slot) }
            if !wasComplete, store.isComplete(routine) {
                Haptics.success()
                onComplete(store.streak(for: routine))
            } else {
                Haptics.tap()
            }
        }
    }
}

private struct SlotToggle: View {
    let name: String
    let time: Date?
    let detail: String?
    let weekly: String?
    let isNext: Bool
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: isNext && !isDone ? 2 : 1.5)
                        .background(Circle().fill(isDone ? Color.primary : .clear))
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.background)
                        .scaleEffect(isDone ? 1 : 0.4)
                        .opacity(isDone ? 1 : 0)
                }
                .frame(width: 46, height: 46)

                VStack(spacing: 1) {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isDone ? .primary : .secondary)
                    if let time {
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(isNext ? Theme.accent : Color.secondary)
                    } else if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let weekly {
                        Text(weekly)
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel([name, time?.formatted(date: .omitted, time: .shortened), detail, weekly].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(isDone ? "Done" : (isNext ? "Next" : "Not done"))
        .accessibilityAddTraits(.isButton)
    }

    private var ringColor: Color {
        if isDone { return .clear }
        return isNext ? Theme.accent : Color.primary.opacity(0.15)
    }
}
