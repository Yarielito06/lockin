import SwiftUI

// MARK: - Goal

/// Create or edit a goal: what, which day, and a symbol.
struct GoalEditorView: View {
    var goal: Goal?

    @EnvironmentObject private var planner: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var symbol = Goal.symbols[0]
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var note = ""
    @State private var isConfirmingDelete = false

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    field("What are you working towards?") {
                        TextField("Study, Marathon, Final exam…", text: $title)
                            .submitLabel(.done)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    field("The big day") {
                        DatePicker("Date", selection: $date, in: Date.now..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Theme.accent)
                            .padding(10)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    field("Symbol") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                            ForEach(Goal.symbols, id: \.self) { option in
                                Button {
                                    Haptics.select()
                                    symbol = option
                                } label: {
                                    Image(systemName: option)
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .foregroundStyle(symbol == option ? Theme.background : .primary)
                                        .background(symbol == option ? Color.primary : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    field("Note (optional)") {
                        TextField("Which chapters, who with…", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(14)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if goal != nil {
                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Label("Delete goal", systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.red.opacity(0.1), in: Capsule())
                        }
                        .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .navigationTitle(goal == nil ? "New goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).font(.body.weight(.semibold)).disabled(trimmed.isEmpty)
                }
            }
            .confirmationDialog("Delete this goal?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let goal { planner.delete(goal) }
                    dismiss()
                }
            }
            .onAppear {
                guard let goal else { return }
                title = goal.title
                symbol = goal.symbol
                date = goal.targetDate
                note = goal.note
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        var new = goal ?? Goal(title: trimmed, targetDate: date)
        new.title = trimmed
        new.symbol = symbol
        new.targetDate = date
        new.note = note
        planner.save(new)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Deadline, exam, event or to-do

struct PlanItemEditorView: View {
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
    @State private var note = ""
    @State private var isConfirmingDelete = false

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var dayCount: Int {
        let calendar = Calendar.current
        return max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: endDate)).day ?? 0) + 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    field("What is it?") {
                        TextField("Essay due, Maths exam, Dentist…", text: $title)
                            .submitLabel(.done)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    field("Type") {
                        HStack(spacing: 8) {
                            ForEach(PlanKind.allCases) { option in
                                Button {
                                    Haptics.select()
                                    withAnimation(Theme.spring) { kind = option }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: option.symbol).font(.system(size: 16, weight: .semibold))
                                        Text(option.title).font(.caption.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 58)
                                    .foregroundStyle(kind == option ? .white : option.color)
                                    .background(kind == option ? option.color : option.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    field(hasEnd ? "From" : "When") {
                        VStack(spacing: 0) {
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(kind.color)
                                .padding(10)
                                .onChange(of: date) { newDate in
                                    if endDate < newDate { endDate = newDate }
                                }
                            Divider().padding(.horizontal, 14)
                            Toggle("It runs over several days", isOn: $hasEnd.animation(Theme.spring))
                                .tint(kind.color)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            if hasEnd {
                                HStack {
                                    DatePicker("Until", selection: $endDate, in: date..., displayedComponents: .date)
                                        .tint(kind.color)
                                    Text("\(dayCount) \(dayCount == 1 ? "day" : "days")")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(kind.color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(kind.color.opacity(0.14), in: Capsule())
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }
                            Divider().padding(.horizontal, 14)
                            Toggle("Add a time", isOn: $hasTime.animation(Theme.spring))
                                .tint(kind.color)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            if hasTime {
                                DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            }
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    field("Note (optional)") {
                        TextField("Details", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(14)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Text("You'll get a reminder on the day, and the evening before a deadline or exam ends.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if item != nil {
                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.red.opacity(0.1), in: Capsule())
                        }
                        .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .navigationTitle(item == nil ? "Add to plan" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).font(.body.weight(.semibold)).disabled(trimmed.isEmpty)
                }
            }
            .confirmationDialog("Delete this?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item { planner.delete(item) }
                    dismiss()
                }
            }
            .onAppear {
                if let item {
                    title = item.title
                    kind = item.kind
                    date = item.date
                    hasTime = item.hasTime
                    note = item.note
                    if item.isPeriod, let end = item.endDate {
                        hasEnd = true
                        endDate = end
                    } else {
                        endDate = item.date
                    }
                } else {
                    date = startDate
                    endDate = Calendar.current.date(byAdding: .day, value: 4, to: startDate) ?? startDate
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        var new = item ?? PlanItem(title: trimmed, date: date)
        new.title = trimmed
        new.kind = kind
        new.date = date
        new.hasTime = hasTime
        new.endDate = hasEnd ? endDate : nil
        new.note = note
        planner.save(new)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Shared

@ViewBuilder
private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        content()
    }
}
