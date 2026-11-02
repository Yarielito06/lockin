import SwiftUI

/// Your calendar: a month with dots for what's planned, the selected day's list, and quick adds.
struct MacPlanView: View {
    @EnvironmentObject private var planner: PlannerStore
    @EnvironmentObject private var routines: RoutineStore

    @State private var month = Date()
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var editingItem: PlanItem?
    @State private var editingGoal: Goal?
    @State private var isAddingItem = false
    @State private var isAddingGoal = false

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Plan").font(.system(size: 40, weight: .bold, design: .rounded))
                    Spacer()
                    addButton("New goal", symbol: "flag.checkered") { isAddingGoal = true }
                    addButton("Add deadline or event", symbol: "plus") { isAddingItem = true }
                }
                HStack(alignment: .top, spacing: 26) {
                    monthCard.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 20) {
                        dayCard
                        ForEach(planner.activeGoals.prefix(2)) { goal in
                            MacGoalCard(goal: goal).onTapGesture { editingGoal = goal }
                        }
                    }
                    .frame(width: 420)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 54)
            .padding(.bottom, 40)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $isAddingItem) { MacItemEditor(startDate: selected) }
        .sheet(item: $editingItem) { MacItemEditor(item: $0) }
        .sheet(isPresented: $isAddingGoal) { MacGoalEditor() }
        .sheet(item: $editingGoal) { MacGoalEditor(goal: $0) }
    }

    private func addButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.accent.opacity(0.18), in: Capsule())
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: Month

    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var result: [Date] = []
        var day = interval.start
        while day < interval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private var monthCard: some View {
        let leading = days.first.map { (calendar.component(.weekday, from: $0) - calendar.firstWeekday + 7) % 7 } ?? 0
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return VStack(spacing: 16) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                navButton("chevron.left") { shift(-1) }
                navButton("calendar") { month = .now; selected = calendar.startOfDay(for: .now) }
                navButton("chevron.right") { shift(1) }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let symbol = calendar.shortWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7]
                    Text(symbol.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 64) }
                ForEach(days, id: \.self) { day in dayCell(day) }
            }
        }
        .glassCard(padding: 22, radius: 30)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func shift(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(Theme.spring) { month = next }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        let items = planner.items(on: day).filter { !$0.isDone }
        return Button {
            Haptics.select()
            withAnimation(Theme.spring) { selected = calendar.startOfDay(for: day) }
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 17, weight: isToday ? .bold : .medium)).monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.accent : Color.primary))
                HStack(spacing: 3) {
                    if planner.hasGoal(on: day) { Image(systemName: "flag.fill").font(.system(size: 8)).foregroundStyle(isSelected ? .white : Theme.accent) }
                    ForEach(Array(items.prefix(3))) { item in
                        Capsule().fill(isSelected ? Color.white : item.kind.color).frame(width: item.isPeriod ? 14 : 6, height: 5)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(isToday ? 0.12 : 0.05)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Day

    private var dayCard: some View {
        let items = planner.items(on: selected)
        let goals = planner.goals(on: selected)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(calendar.isDateInToday(selected) ? "Today" : selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                Button { isAddingItem = true } label: {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30).background(Theme.accent.opacity(0.2), in: Circle()).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            if items.isEmpty && goals.isEmpty {
                Text("Nothing planned. Add a deadline, an exam or a to-do.").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            ForEach(goals) { goal in
                Label("Goal day: \(goal.title)", systemImage: "flag.checkered").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
            }
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        withAnimation(Theme.spring) { planner.toggle(item) }
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                            .foregroundStyle(item.isDone ? item.kind.color : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.system(size: 16, weight: .semibold))
                            .strikethrough(item.isDone, color: .secondary)
                        HStack(spacing: 5) {
                            Image(systemName: item.kind.symbol).font(.system(size: 10)).foregroundStyle(item.kind.color)
                            Text(item.isPeriod ? "\(item.kind.title) · \(item.dateLabel)" : (item.hasTime ? "\(item.kind.title) · \(item.date.formatted(date: .omitted, time: .shortened))" : item.kind.title))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { editingItem = item }
            }
        }
        .glassCard(padding: 20, radius: 28)
    }
}

// MARK: - Editors

struct MacItemEditor: View {
    var item: PlanItem?
    var startDate: Date = .now

    @EnvironmentObject private var planner: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var kind: PlanKind = .deadline
    @State private var date = Date.now
    @State private var hasTime = false
    @State private var hasEnd = false
    @State private var endDate = Date.now
    @State private var leadDays = 3
    @State private var nudge = true
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(item == nil ? "Add to plan" : "Edit").font(.system(size: 24, weight: .bold, design: .rounded))
            TextField("Essay due, Maths exam, Dentist…", text: $title).textFieldStyle(.roundedBorder).font(.system(size: 16))
            Picker("Type", selection: $kind) {
                ForEach(PlanKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            DatePicker(hasEnd ? "From" : "Date", selection: $date, displayedComponents: hasTime ? [.date, .hourAndMinute] : .date)
            Toggle("Add a time", isOn: $hasTime)
            Toggle("It runs over several days", isOn: $hasEnd)
            if hasEnd { DatePicker("Until", selection: $endDate, in: date..., displayedComponents: .date) }
            Picker("Remind me", selection: $leadDays) {
                Text("No").tag(0); Text("1 day before").tag(1); Text("3 days before").tag(3); Text("1 week before").tag(7)
            }
            Toggle("Nudge me each morning until it's done", isOn: $nudge)
            TextField("Note (optional)", text: $note).textFieldStyle(.roundedBorder)
            HStack {
                if let item {
                    Button("Delete", role: .destructive) { planner.delete(item); dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 480)
        .onAppear {
            if let item {
                title = item.title; kind = item.kind; date = item.date; hasTime = item.hasTime
                leadDays = item.leadDays; nudge = item.nudge; note = item.note
                hasEnd = item.isPeriod; endDate = item.endDate ?? item.date
            } else {
                date = startDate
                endDate = Calendar.current.date(byAdding: .day, value: 4, to: startDate) ?? startDate
            }
        }
    }

    private func save() {
        var new = item ?? PlanItem(title: title, date: date)
        new.title = title.trimmingCharacters(in: .whitespaces)
        new.kind = kind; new.date = date; new.hasTime = hasTime
        new.endDate = hasEnd ? endDate : nil
        new.leadDays = leadDays; new.nudge = nudge; new.note = note
        planner.save(new)
        dismiss()
    }
}

struct MacGoalEditor: View {
    var goal: Goal?

    @EnvironmentObject private var planner: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var symbol = Goal.symbols[0]
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(goal == nil ? "New goal" : "Edit goal").font(.system(size: 24, weight: .bold, design: .rounded))
            TextField("Study, Marathon, Final exam…", text: $title).textFieldStyle(.roundedBorder).font(.system(size: 16))
            DatePicker("The big day", selection: $date, in: Date.now..., displayedComponents: .date)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(Goal.symbols, id: \.self) { option in
                    Button { symbol = option } label: {
                        Image(systemName: option).font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(symbol == option ? Color.white : Color.primary)
                            .background(symbol == option ? Theme.accent : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                if let goal { Button("Delete", role: .destructive) { planner.delete(goal); dismiss() } }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 460)
        .onAppear {
            if let goal { title = goal.title; symbol = goal.symbol; date = goal.targetDate }
        }
    }

    private func save() {
        var new = goal ?? Goal(title: title, targetDate: date)
        new.title = title.trimmingCharacters(in: .whitespaces)
        new.symbol = symbol
        new.targetDate = date
        planner.save(new)
        dismiss()
    }
}
