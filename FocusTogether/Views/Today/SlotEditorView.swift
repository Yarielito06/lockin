import SwiftUI

/// One routine item: name, short detail, duration and how often — "Gym · 1h · Mon, Wed, Fri".
struct SlotEditorView: View {
    let isNew: Bool
    let onSave: (RoutineSlot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var slot: RoutineSlot
    @State private var frequency: Frequency
    @State private var weekdays: Set<Int>
    @State private var timesPerWeek: Int
    @FocusState private var isNameFocused: Bool

    private enum Frequency: String, CaseIterable {
        case daily = "Every day"
        case days = "Some days"
        case perWeek = "Per week"
    }

    private static let durations = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180]

    init(slot: RoutineSlot, isNew: Bool, onSave: @escaping (RoutineSlot) -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        _slot = State(initialValue: slot)
        switch slot.effectiveSchedule {
        case .daily:
            _frequency = State(initialValue: .daily)
            _weekdays = State(initialValue: [2, 4, 6])
            _timesPerWeek = State(initialValue: 3)
        case .days(let days):
            _frequency = State(initialValue: .days)
            _weekdays = State(initialValue: days)
            _timesPerWeek = State(initialValue: 3)
        case .perWeek(let times):
            _frequency = State(initialValue: .perWeek)
            _weekdays = State(initialValue: [2, 4, 6])
            _timesPerWeek = State(initialValue: times)
        }
    }

    private var trimmedName: String { slot.name.trimmingCharacters(in: .whitespaces) }

    private var canSave: Bool {
        !trimmedName.isEmpty && (frequency != .days || !weekdays.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name — e.g. Water, Gym, Study", text: $slot.name)
                        .font(.body.weight(.medium))
                        .focused($isNameFocused)
                    TextField("Detail — e.g. 2L, 5 km, Chapter 3", text: Binding(
                        get: { slot.note ?? "" },
                        set: { slot.note = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Duration") {
                    Picker("How long", selection: $slot.minutes) {
                        Text("None").tag(Int?.none)
                        ForEach(Self.durations, id: \.self) { minutes in
                            Text(SlotSchedule.durationLabel(minutes)).tag(Int?.some(minutes))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }

                if slot.prayer == nil {
                    Section {
                        Picker("How often", selection: $frequency) {
                            ForEach(Frequency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                        switch frequency {
                        case .daily:
                            EmptyView()
                        case .days:
                            weekdayPicker
                        case .perWeek:
                            Stepper(value: $timesPerWeek, in: 1...6) {
                                Text(timesPerWeek == 1 ? "Once a week" : "\(timesPerWeek)× a week")
                                    .font(.body.weight(.medium))
                            }
                        }
                    } header: {
                        Text("How often")
                    } footer: {
                        Text(footer)
                    }
                }

                Section {
                    HStack {
                        Text("Shows as")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(preview)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(isNew ? "New item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done", action: save)
                        .font(.body.weight(.semibold))
                        .disabled(!canSave)
                }
            }
            .onAppear { if isNew { isNameFocused = true } }
        }
        .presentationDetents([.large])
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(spacing: 6) {
            ForEach(SlotSchedule.orderedWeekdays, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button {
                    Haptics.select()
                    if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(symbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? Theme.background : .primary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(isOn ? Color.primary : Theme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var schedule: SlotSchedule {
        switch frequency {
        case .daily: .daily
        case .days: .days(weekdays)
        case .perWeek: .perWeek(timesPerWeek)
        }
    }

    private var footer: String {
        switch frequency {
        case .daily: "Shows on Today every day."
        case .days: "Only shows on the days you pick. Other days don't break your streak."
        case .perWeek: "Shows until you've done it enough times this week."
        }
    }

    private var preview: String {
        var draft = slot
        draft.name = trimmedName.isEmpty ? "Item" : trimmedName
        draft.schedule = schedule
        return [draft.name, draft.detailText, slot.prayer == nil ? schedule.label : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func save() {
        var result = slot
        result.name = trimmedName
        result.note = slot.note?.trimmingCharacters(in: .whitespaces)
        if result.note?.isEmpty == true { result.note = nil }
        result.schedule = slot.prayer == nil ? schedule : nil
        Haptics.success()
        onSave(result)
        dismiss()
    }
}
