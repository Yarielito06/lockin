import SwiftUI

/// Your week (or month) at a glance: how much of each day's routines you did, focus time,
/// and a breakdown of any day you tap.
struct CalendarView: View {
    @EnvironmentObject private var routines: RoutineStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var planner: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingItem: PlanItem?
    @State private var editingGoal: Goal?
    @State private var isAddingItem = false
    @State private var isAddingGoal = false

    private enum Mode: String, CaseIterable {
        case week = "Week"
        case month = "Month"
    }

    @State private var mode: Mode = .week
    @State private var anchor = Date()
    @State private var selected = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PillPicker(options: Mode.allCases, selection: $mode) { $0.rawValue }

                    VStack(spacing: 16) {
                        periodHeader
                        if mode == .week { weekStrip } else { monthGrid }
                    }
                    .card(padding: 16)
                    .animation(Theme.spring, value: mode)

                    summary
                    DayPlan(date: selected, onEditItem: { editingItem = $0 }, onAdd: { isAddingItem = true })
                    UpcomingList(onEditItem: { editingItem = $0 }, onEditGoal: { editingGoal = $0 })
                    DayDetail(date: selected)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button { isAddingItem = true } label: { Label("Deadline, exam or event", systemImage: "calendar.badge.plus") }
                        Button { isAddingGoal = true } label: { Label("New goal", systemImage: "flag.checkered") }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Theme.accent)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isAddingItem) { PlanItemEditorView(startDate: selected) }
            .sheet(item: $editingItem) { PlanItemEditorView(item: $0) }
            .sheet(isPresented: $isAddingGoal) { GoalEditorView() }
            .sheet(item: $editingGoal) { GoalEditorView(goal: $0) }
        }
    }

    // MARK: Period navigation

    private var periodDays: [Date] {
        let component: Calendar.Component = mode == .week ? .weekOfYear : .month
        guard let interval = calendar.dateInterval(of: component, for: anchor) else { return [] }
        var days: [Date] = []
        var day = interval.start
        while day < interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    private var periodTitle: String {
        if mode == .month {
            return anchor.formatted(.dateTime.month(.wide).year())
        }
        guard let first = periodDays.first, let last = periodDays.last else { return "" }
        if calendar.isDate(first, equalTo: .now, toGranularity: .weekOfYear) { return "This week" }
        return "\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var canGoForward: Bool {
        let component: Calendar.Component = mode == .week ? .weekOfYear : .month
        return !calendar.isDate(anchor, equalTo: .now, toGranularity: component)
    }

    private var periodHeader: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            .accessibilityLabel("Previous")
            Spacer()
            Text(periodTitle)
                .font(.headline)
                .contentTransition(.opacity)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.25)
            .accessibilityLabel("Next")
        }
        .foregroundStyle(.primary)
    }

    private func shift(_ value: Int) {
        let component: Calendar.Component = mode == .week ? .weekOfYear : .month
        guard let next = calendar.date(byAdding: component, value: value, to: anchor) else { return }
        Haptics.select()
        withAnimation(Theme.spring) {
            anchor = next
            // Keep the selection inside the visible period.
            if !calendar.isDate(selected, equalTo: next, toGranularity: component) {
                selected = calendar.isDate(next, equalTo: .now, toGranularity: component)
                    ? calendar.startOfDay(for: .now)
                    : (periodDays.first ?? next)
            }
        }
    }

    // MARK: Week

    private var weekStrip: some View {
        HStack(spacing: 4) {
            ForEach(periodDays, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selected)
                let isToday = calendar.isDateInToday(day)
                Button { select(day) } label: {
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ZStack {
                            ring(for: day, lineWidth: 4)
                            Text(day.formatted(.dateTime.day()))
                                .font(.subheadline.weight(isToday ? .bold : .medium).monospacedDigit())
                                .foregroundStyle(isFuture(day) ? Color.secondary : .primary)
                        }
                        .frame(width: 38, height: 38)
                        planDots(for: day)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Theme.background : .clear)
                            .shadow(color: .black.opacity(isSelected ? 0.06 : 0), radius: 6, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibility(for: day))
            }
        }
    }

    // MARK: Month

    private var monthGrid: some View {
        let days = periodDays
        let leading = days.first.map { (calendar.component(.weekday, from: $0) - calendar.firstWeekday + 7) % 7 } ?? 0
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        let symbols = calendar.veryShortWeekdaySymbols
        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(SlotSchedule.orderedWeekdays, id: \.self) { weekday in
                    Text(symbols[weekday - 1])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 38) }
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selected)
                    Button { select(day) } label: {
                        VStack(spacing: 2) {
                            Text(day.formatted(.dateTime.day()))
                                .font(.caption.weight(calendar.isDateInToday(day) ? .bold : .medium).monospacedDigit())
                                .foregroundStyle(heatTextColor(for: day))
                            planDots(for: day, onHeat: true)
                        }
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(heatColor(for: day), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primary, lineWidth: isSelected ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibility(for: day))
                }
            }
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 0.34, 0.67, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Theme.track : Theme.accent.opacity(0.25 + level * 0.75))
                        .frame(width: 12, height: 12)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: Summary

    private var summary: some View {
        let past = periodDays.filter { !isFuture($0) && $0 >= routines.firstTrackedDay }
        let totals = past.map(routines.progress(on:))
        let done = totals.reduce(0) { $0 + $1.done }
        let due = totals.reduce(0) { $0 + $1.due }
        let perfect = totals.filter { $0.due > 0 && $0.done == $0.due }.count
        let focus = periodDays.reduce(0) { sum, day in sum + history.sessions(on: day).reduce(0) { $0 + $1.minutes } }
        let percent = due == 0 ? 0 : Int((Double(done) / Double(due) * 100).rounded())

        return HStack(spacing: 0) {
            stat("\(percent)%", "Done", symbol: "checkmark.circle.fill")
            Divider().frame(height: 32)
            stat(focus.minutesLabel, "Focus", symbol: "lock.fill")
            Divider().frame(height: 32)
            stat("\(perfect)", perfect == 1 ? "Perfect day" : "Perfect days", symbol: "star.fill")
        }
        .card(padding: 16)
    }

    private func stat(_ value: String, _ label: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    /// Small dots for things planned on a day: a goal's day, and each kind of item.
    @ViewBuilder
    private func planDots(for day: Date, onHeat: Bool = false) -> some View {
        let kinds = Set(planner.items(on: day).filter { !$0.isDone }.map(\.kind))
        let hasGoal = planner.hasGoal(on: day)
        HStack(spacing: 3) {
            if hasGoal { Image(systemName: "flag.fill").font(.system(size: 6)).foregroundStyle(onHeat ? Color.primary : Theme.accent) }
            ForEach(PlanKind.allCases.filter { kinds.contains($0) }.prefix(3)) { kind in
                Circle().fill(kind.color).frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
    }

    private func select(_ day: Date) {
        Haptics.select()
        withAnimation(Theme.spring) { selected = calendar.startOfDay(for: day) }
    }

    private func isFuture(_ day: Date) -> Bool {
        calendar.startOfDay(for: day) > calendar.startOfDay(for: .now)
    }

    private func ratio(for day: Date) -> Double? {
        guard !isFuture(day), day >= routines.firstTrackedDay else { return nil }
        let progress = routines.progress(on: day)
        guard progress.due > 0 else { return nil }
        return Double(progress.done) / Double(progress.due)
    }

    @ViewBuilder
    private func ring(for day: Date, lineWidth: CGFloat) -> some View {
        if let ratio = ratio(for: day) {
            ZStack {
                if ratio >= 1 {
                    Circle().fill(Theme.accent.opacity(0.15))
                }
                ProgressRing(progress: ratio, lineWidth: lineWidth)
            }
        } else {
            Circle().stroke(Theme.track, style: StrokeStyle(lineWidth: lineWidth, dash: isFuture(day) ? [2, 4] : []))
        }
    }

    private func heatColor(for day: Date) -> Color {
        guard let ratio = ratio(for: day), ratio > 0 else { return Theme.track }
        return Theme.accent.opacity(0.25 + ratio * 0.75)
    }

    private func heatTextColor(for day: Date) -> Color {
        if isFuture(day) { return .secondary }
        if let ratio = ratio(for: day), ratio >= 0.67 { return .white }
        return .primary
    }

    private func accessibility(for day: Date) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let ratio = ratio(for: day) else { return date }
        return "\(date), \(Int(ratio * 100)) percent done"
    }
}

/// What happened on one day: totals, focus sessions and each routine's items.
private struct DayDetail: View {
    let date: Date

    @EnvironmentObject private var routines: RoutineStore
    @EnvironmentObject private var history: HistoryStore

    private let calendar = Calendar.current

    private var isFuture: Bool { calendar.startOfDay(for: date) > calendar.startOfDay(for: .now) }
    private var isUntracked: Bool { !isFuture && date < routines.firstTrackedDay }

    private var title: String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        let progress = routines.progress(on: date)
        let sessions = history.sessions(on: date)
        let focus = sessions.reduce(0) { $0 + $1.minutes }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.bold())
                Spacer()
                if !isFuture, !isUntracked, progress.due > 0 {
                    Text("\(progress.done) of \(progress.due) done")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(progress.done == progress.due ? Theme.accent : .secondary)
                }
            }

            if !sessions.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Locked in for \(focus.minutesLabel)")
                            .font(.subheadline.weight(.semibold))
                        Text(sessions.count == 1 ? "1 session" : "\(sessions.count) sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .card(padding: 12)
            }

            if routines.routines.isEmpty {
                Text("Add a routine to see your days here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isUntracked {
                Text("Nothing tracked yet on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(routines.routines) { routine in
                    routineSection(routine)
                }
            }
        }
        .animation(Theme.spring, value: date)
    }

    private func routineSection(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(routine.name, systemImage: routine.symbol)
                .font(.subheadline.weight(.semibold))
            VStack(spacing: 0) {
                ForEach(Array(routine.slots.enumerated()), id: \.element.id) { index, slot in
                    if index > 0 { Divider().padding(.leading, 34) }
                    row(slot, in: routine)
                }
            }
        }
        .card(padding: 14)
    }

    private enum Status { case done, missed, upcoming, notDue }

    private func status(of slot: RoutineSlot, in routine: Routine) -> Status {
        let due = routines.dueSlots(in: routine, on: date).contains { $0.id == slot.id }
        if routines.isDone(slot, on: date) { return .done }
        if !due { return .notDue }
        if isFuture || calendar.isDateInToday(date) { return .upcoming }
        return .missed
    }

    private func row(_ slot: RoutineSlot, in routine: Routine) -> some View {
        let status = status(of: slot, in: routine)
        return HStack(spacing: 12) {
            Group {
                switch status {
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                case .missed:
                    Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                case .upcoming:
                    Image(systemName: "circle").foregroundStyle(.secondary)
                case .notDue:
                    Image(systemName: "minus.circle").foregroundStyle(.tertiary)
                }
            }
            .font(.title3)
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(slot.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(status == .notDue ? .secondary : .primary)
                    .strikethrough(status == .missed, color: .secondary)
                if let detail = slot.detailText {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(label(for: status))
                .font(.caption.weight(.medium))
                .foregroundStyle(status == .done ? Theme.accent : .secondary)
        }
        .padding(.vertical, 8)
    }

    private func label(for status: Status) -> String {
        switch status {
        case .done: "Done"
        case .missed: "Missed"
        case .upcoming: isFuture ? "Planned" : "To do"
        case .notDue: "Not due"
        }
    }
}
