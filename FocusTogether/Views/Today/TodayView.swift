import SwiftUI

/// The first tab: daily routines (prayers, habits, anything) with tick-off slots.
struct TodayView: View {
    @EnvironmentObject private var store: RoutineStore
    @State private var isAdding = false
    @State private var editing: Routine?
    @State private var deleting: Routine?
    @State private var toast: String?
    @State private var isShowingCalendar = false
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        title: "Today",
                        subtitle: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
                    ) {
                        CircleIconButton(systemName: "plus", accessibilityLabel: "Add routine") {
                            isAdding = true
                        }
                    }

                    if store.routines.isEmpty {
                        emptyState
                    } else {
                        progressCard
                        ForEach(store.routines) { routine in
                            RoutineCard(
                                routine: routine,
                                onEdit: { editing = routine },
                                onDelete: { deleting = routine },
                                onComplete: { streak in celebrate(routine, streak: streak) }
                            )
                            .contextMenu {
                                Button { editing = routine } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) { deleting = routine } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.primary, in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Theme.spring, value: toast)
            .sheet(isPresented: $isShowingCalendar) { CalendarView() }
            .sheet(isPresented: $isAdding) {
                AddRoutineFlow()
            }
            .sheet(item: $editing) { routine in
                NavigationStack {
                    RoutineEditorView(mode: .edit(routine)) { editing = nil }
                }
            }
            .confirmationDialog(
                "Delete \(deleting?.name ?? "routine")?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let routine = deleting {
                        Haptics.tap()
                        withAnimation(Theme.spring) { store.delete(routine) }
                    }
                    deleting = nil
                }
            } message: {
                Text("Its reminders and today's ticks go with it.")
            }
        }
    }

    private func celebrate(_ routine: Routine, streak: Int) {
        toast = streak > 1
            ? "\(routine.name) complete · 🔥 \(streak)-day streak"
            : "\(routine.name) complete · streak started 🔥"
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    private var progressCard: some View {
        let progress = store.todayProgress
        let fraction = progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
        return Button {
            Haptics.tap()
            isShowingCalendar = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(progress.done) of \(progress.total)")
                            .font(.title2.bold().monospacedDigit())
                            .contentTransition(.numericText())
                        Text(fraction >= 1 ? "All done today. Beautiful." : "done today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProgressRing(progress: fraction, lineWidth: 7)
                        .frame(width: 52, height: 52)
                }
                Divider()
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        VStack(spacing: 6) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Calendar.current.isDateInToday(day) ? .primary : .secondary)
                            weekDot(day)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
            .foregroundStyle(.primary)
            .card(padding: 20)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your week and past days")
        .animation(Theme.spring, value: progress.done)
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Filled orange when the day was completed, partly filled when started, outlined otherwise.
    private func weekDot(_ day: Date) -> some View {
        let calendar = Calendar.current
        let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: .now)
        let p = store.progress(on: day)
        let ratio = (isFuture || p.due == 0 || day < store.firstTrackedDay) ? 0 : Double(p.done) / Double(p.due)
        return ZStack {
            Circle().fill(ratio >= 1 ? Theme.accent : Theme.track)
            if ratio > 0, ratio < 1 {
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5)
            }
            if ratio >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 16, height: 16)
        .overlay(
            Circle().strokeBorder(Color.primary, lineWidth: calendar.isDateInToday(day) ? 1.5 : 0).padding(-3)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Build your daily rhythm")
                    .font(.title3.bold())
                Text("Prayer, habits, study — anything you do every day, ticked off in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                isAdding = true
            } label: {
                Label("Add a routine", systemImage: "plus")
            }
            .buttonStyle(.primary)
        }
        .card(padding: 20)
    }
}
