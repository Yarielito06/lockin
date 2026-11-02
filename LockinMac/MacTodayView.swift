import SwiftUI

/// Your day: routines on the left, goals and what's coming up on the right.
struct MacTodayView: View {
    @EnvironmentObject private var routines: RoutineStore
    @EnvironmentObject private var planner: PlannerStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var focus: MacFocus

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                HStack(alignment: .top, spacing: 26) {
                    VStack(alignment: .leading, spacing: 18) { routinesColumn }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    VStack(alignment: .leading, spacing: 22) {
                        goals
                        upcoming
                    }
                    .frame(width: 400, alignment: .topLeading)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 54)
            .padding(.bottom, 40)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Header

    private var header: some View {
        let progress = routines.todayProgress
        let fraction = progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
        return HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(greeting)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 22) {
                stat("\(progress.done)/\(progress.total)", "done today", ring: fraction)
                stat(history.todayMinutes.minutesLabel, "focused today")
                stat("\(history.streakDays)", "day streak", flame: true)
            }
            .glassCard(padding: 18, radius: 26)
            .fixedSize()
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private func stat(_ value: String, _ label: String, ring: Double? = nil, flame: Bool = false) -> some View {
        HStack(spacing: 12) {
            if let ring {
                ZStack {
                    Circle().stroke(Theme.track, lineWidth: 6)
                    Circle().trim(from: 0, to: ring).stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                }
                .frame(width: 44, height: 44)
            } else if flame {
                Image(systemName: "flame.fill").font(.system(size: 24)).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Routines

    @ViewBuilder
    private var routinesColumn: some View {
        if routines.routines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "iphone.and.arrow.forward").font(.system(size: 30)).foregroundStyle(Theme.accent)
                Text("Your routines come from your iPhone")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Add a routine in Lockin on your iPhone and it appears here through iCloud, with the same Apple ID. You can tick things off from this Mac too.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .glassCard(padding: 24, radius: 28)
        } else {
            ForEach(routines.routines) { routine in
                routineCard(routine)
            }
        }
    }

    private func routineCard(_ routine: Routine) -> some View {
        let due = routines.dueSlots(in: routine)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: routine.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent.opacity(0.16), in: Circle())
                Text(routine.name).font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                Text("\(routines.doneCount(in: routine))/\(due.count)")
                    .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if due.isEmpty {
                Label("Nothing due today — rest day", systemImage: "moon.zzz")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(due) { slot in slotRow(slot) }
                }
            }
        }
        .glassCard(padding: 20, radius: 28)
    }

    private func slotRow(_ slot: RoutineSlot) -> some View {
        let done = routines.isDone(slot)
        return Button {
            withAnimation(Theme.spring) { routines.toggle(slot) }
            Haptics.tap()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(done ? Color.clear : Color.primary.opacity(0.25), lineWidth: 1.8)
                        .background(Circle().fill(done ? Theme.accent : .clear))
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .opacity(done ? 1 : 0).scaleEffect(done ? 1 : 0.4)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(slot.name).font(.system(size: 17, weight: .semibold))
                        .strikethrough(done, color: .secondary)
                        .foregroundStyle(done ? .secondary : .primary)
                    if let detail = slot.detailText {
                        Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if case .perWeek(let target) = slot.effectiveSchedule {
                    Text("\(routines.doneThisWeek(slot))/\(target) this week")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Goals and upcoming

    @ViewBuilder
    private var goals: some View {
        let list = planner.activeGoals
        if list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("No goal yet", systemImage: "flag.checkered").font(.system(size: 19, weight: .bold, design: .rounded))
                Text("Set one on the Plan tab, or on your iPhone.").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .glassCard(padding: 20, radius: 26)
        } else {
            ForEach(list.prefix(3)) { goal in MacGoalCard(goal: goal) }
        }
    }

    private var upcoming: some View {
        let entries = planner.upcoming(limit: 6)
        return Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coming up").font(.system(size: 19, weight: .bold, design: .rounded))
                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: entry.symbol).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(entry.color)
                                    .frame(width: 34, height: 34)
                                    .background(entry.color.opacity(0.16), in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                    Text(entry.dateLabel).font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.relativeLabel()).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .glassCard(padding: 20, radius: 26)
            }
        }
    }
}

/// A goal as a warm poster card with its countdown.
struct MacGoalCard: View {
    let goal: Goal
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let days = goal.daysLeft()
        let minutes = history.records.filter { $0.endDate >= goal.createdAt }.reduce(0) { $0 + $1.minutes }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.symbol).font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40).background(.white.opacity(0.22), in: Circle())
                Spacer()
                Text(goal.targetDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.22), in: Capsule())
            }
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(max(0, days))").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                Text(days == 1 ? "day to go" : "days to go").font(.system(size: 16, weight: .semibold)).opacity(0.9)
            }
            Text(goal.title).font(.system(size: 19, weight: .bold, design: .rounded))
            GeometryReader { geo in
                Capsule().fill(.white.opacity(0.28)).overlay(alignment: .leading) {
                    Capsule().fill(.white).frame(width: max(8, geo.size.width * goal.timeProgress()))
                }
            }
            .frame(height: 7)
            Text(minutes > 0 ? "Locked in \(minutes.minutesLabel) since you set this goal" : "Lock in to start counting your time")
                .font(.system(size: 13)).opacity(0.92)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.25), Color(red: 0.95, green: 0.30, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.15).opacity(0.32), radius: 18, y: 8)
    }
}
