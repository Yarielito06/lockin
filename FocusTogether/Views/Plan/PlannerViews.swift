import SwiftUI

// MARK: - Goal card

/// A goal as a warm poster card: days to go, the day, and how much you've locked in towards it.
struct GoalCard: View {
    let goal: Goal
    var width: CGFloat? = nil

    @EnvironmentObject private var history: HistoryStore

    private var days: Int { goal.daysLeft() }

    private var minutesSince: Int {
        history.records.filter { $0.endDate >= goal.createdAt }.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.22), in: Circle())
                Spacer()
                Text(goal.targetDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.22), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(days < 0 ? "Done" : "\(days)")
                    .font(.system(size: days < 0 ? 40 : 58, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if days >= 0 {
                    Text(days == 0 ? "today" : (days == 1 ? "day to go" : "days to go"))
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.9)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)
                GeometryReader { geo in
                    Capsule().fill(.white.opacity(0.28))
                        .overlay(alignment: .leading) {
                            Capsule().fill(.white).frame(width: max(8, geo.size.width * goal.timeProgress()))
                        }
                }
                .frame(height: 6)
                Text(minutesSince > 0 ? "Locked in \(minutesSince.minutesLabel) since you set this goal" : "Lock in to start counting your time")
                    .font(.caption)
                    .opacity(0.9)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.25), Color(red: 0.95, green: 0.30, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.15).opacity(0.28), radius: 16, y: 8)
    }
}

/// The goals on the Today screen: a swipeable row of cards, or an invitation to add the first.
struct GoalsStrip: View {
    @EnvironmentObject private var planner: PlannerStore
    var onAdd: () -> Void
    var onEdit: (Goal) -> Void

    var body: some View {
        let goals = planner.activeGoals
        VStack(alignment: .leading, spacing: 12) {
            if goals.isEmpty {
                Button(action: onAdd) {
                    HStack(spacing: 14) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 46, height: 46)
                            .background(Theme.accent.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set a goal").font(.headline)
                            Text("An exam, a race, a deadline — count down to it.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "plus").foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .card(padding: 16)
                }
                .buttonStyle(.plain)
            } else if goals.count == 1, let goal = goals.first {
                GoalCard(goal: goal)
                    .onTapGesture { onEdit(goal) }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(goals) { goal in
                            GoalCard(goal: goal, width: 290)
                                .onTapGesture { onEdit(goal) }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, -Theme.gutter)
                .contentMargins16()
            }
        }
    }
}

private extension View {
    /// Lets a full-width scroller start at the screen's gutter but scroll edge to edge.
    func contentMargins16() -> some View {
        padding(.horizontal, Theme.gutter)
    }
}

// MARK: - Upcoming

/// The next few things on your plan, soonest first.
struct UpcomingList: View {
    @EnvironmentObject private var planner: PlannerStore
    var onEditItem: (PlanItem) -> Void
    var onEditGoal: (Goal) -> Void

    var body: some View {
        let entries = planner.upcoming()
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Coming up")
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().padding(.leading, 56) }
                        Button {
                            if let item = entry.item { onEditItem(item) } else if let goal = entry.goal { onEditGoal(goal) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: entry.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(entry.color)
                                    .frame(width: 38, height: 38)
                                    .background(entry.color.opacity(0.14), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.relativeLabel())
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(entry.relativeLabel().hasSuffix("ago") ? Color.red : Color.secondary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card(padding: 14)
            }
        }
    }
}

// MARK: - A day's plan

/// The items on one day, with a tick for each and a quick way to add more.
struct DayPlan: View {
    let date: Date
    var onEditItem: (PlanItem) -> Void
    var onAdd: () -> Void

    @EnvironmentObject private var planner: PlannerStore

    var body: some View {
        let items = planner.items(on: date)
        let goals = planner.goals(on: date)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Plan", systemImage: "calendar.badge.clock").font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onAdd) {
                    Label("Add", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }
            }
            if items.isEmpty && goals.isEmpty {
                Text("Nothing planned. Add a deadline, an exam or a to-do.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(goals) { goal in
                        HStack(spacing: 12) {
                            Image(systemName: "flag.checkered").foregroundStyle(Theme.accent).frame(width: 22)
                            Text("Goal day: \(goal.title)").font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 || !goals.isEmpty { Divider().padding(.leading, 34) }
                        HStack(spacing: 12) {
                            Button {
                                Haptics.tap()
                                withAnimation(Theme.spring) { planner.toggle(item) }
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isDone ? item.kind.color : Color.secondary)
                                    .frame(width: 22)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .strikethrough(item.isDone, color: .secondary)
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                HStack(spacing: 6) {
                                    Image(systemName: item.kind.symbol).font(.caption2).foregroundStyle(item.kind.color)
                                    Text(item.hasTime ? "\(item.kind.title) · \(item.date.formatted(date: .omitted, time: .shortened))" : item.kind.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture { onEditItem(item) }
                    }
                }
            }
        }
        .card(padding: 14)
    }
}
