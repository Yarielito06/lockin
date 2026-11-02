import SwiftUI

/// Name, icon and slots for a routine — plus prayer-time settings for Salah.
/// Used inside the add flow (create) and on its own (edit); `onFinish` closes whichever sheet it's in.
struct RoutineEditorView: View {
    enum Mode {
        case create(Routine)
        case edit(Routine)
    }

    let mode: Mode
    let onFinish: () -> Void

    @EnvironmentObject private var store: RoutineStore

    @State private var routine: Routine
    @State private var locator = LocationFetcher()
    @State private var isRelocating = false
    @State private var notificationsDenied = false
    @State private var editingSlot: RoutineSlot?
    @State private var isNewSlot = false

    init(mode: Mode, onFinish: @escaping () -> Void) {
        self.mode = mode
        self.onFinish = onFinish
        switch mode {
        case .create(let draft), .edit(let draft):
            _routine = State(initialValue: draft)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var cleaned: Routine {
        var result = routine
        result.name = routine.name.trimmingCharacters(in: .whitespaces)
        result.slots = routine.slots
            .map { slot in
                var slot = slot
                slot.name = slot.name.trimmingCharacters(in: .whitespaces)
                return slot
            }
            .filter { !$0.name.isEmpty }
        return result
    }

    private var canSave: Bool {
        !cleaned.name.isEmpty && !cleaned.slots.isEmpty
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Gym, Reading, Journal", text: $routine.name)
                    .font(.body.weight(.medium))
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(RoutineDrafts.symbols, id: \.self) { option in
                        let isSelected = routine.symbol == option
                        Button {
                            Haptics.select()
                            routine.symbol = option
                        } label: {
                            Image(systemName: option)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isSelected ? Theme.background : .primary)
                                .frame(width: 44, height: 44)
                                .background(isSelected ? Color.primary : Theme.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                ForEach(routine.slots) { slot in
                    Button {
                        isNewSlot = false
                        editingSlot = slot
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.name.isEmpty ? "Untitled" : slot.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(summary(of: slot))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { routine.slots.remove(atOffsets: $0) }

                Button {
                    isNewSlot = true
                    editingSlot = RoutineSlot(name: "")
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.body.weight(.medium))
                }
            } header: {
                Text("Items")
            } footer: {
                Text("Tap an item to set a detail (2L), a duration (15 min) and how often. Swipe left to remove.")
            }

            if routine.prayerSettings != nil {
                Section("Prayer times") {
                    PrayerSettingsCard(settings: Binding(
                        get: { routine.prayerSettings! },
                        set: { routine.prayerSettings = $0 }
                    ))
                    .listRowInsets(EdgeInsets())

                    Button(action: relocate) {
                        if isRelocating {
                            ProgressView()
                        } else {
                            Label("Update my location", systemImage: "location")
                        }
                    }
                    .disabled(isRelocating)
                }
            }

            Section {
                if routine.prayerSettings != nil {
                    PrayerReminderPicker(minutes: $routine.prayerReminderMinutes)
                } else {
                    Toggle("Daily reminder", isOn: dailyReminderOn)
                        .tint(Theme.accent)
                    if routine.reminderTime != nil {
                        DatePicker("Time", selection: reminderDate, displayedComponents: .hourAndMinute)
                    }
                }
                if notificationsDenied {
                    Text("Notifications are off for Lockin. Turn them on in Settings › Notifications › Lockin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Reminder")
            }
            .onChange(of: routine.prayerReminderMinutes) { if $0 != nil { askForNotifications() } }
            .onChange(of: routine.reminderTime) { if $0 != nil { askForNotifications() } }

            if isEditing {
                Section {
                    Button("Delete routine", role: .destructive) {
                        store.delete(routine)
                        onFinish()
                    }
                }
            }
        }
        .sheet(item: $editingSlot) { slot in
            SlotEditorView(slot: slot, isNew: isNewSlot) { updated in
                if let index = routine.slots.firstIndex(where: { $0.id == updated.id }) {
                    routine.slots[index] = updated
                } else {
                    routine.slots.append(updated)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit routine" : (routine.name.isEmpty ? "New routine" : routine.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onFinish)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add", action: save)
                    .font(.body.weight(.semibold))
                    .disabled(!canSave)
            }
        }
    }

    private var dailyReminderOn: Binding<Bool> {
        Binding(
            get: { routine.reminderTime != nil },
            set: { routine.reminderTime = $0 ? ReminderTime(hour: 8, minute: 0) : nil }
        )
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                let time = routine.reminderTime ?? ReminderTime(hour: 8, minute: 0)
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                routine.reminderTime = ReminderTime(hour: parts.hour ?? 8, minute: parts.minute ?? 0)
            }
        )
    }

    private func askForNotifications() {
        Task {
            await ReminderScheduler.requestPermission()
            notificationsDenied = await ReminderScheduler.isDenied()
        }
    }

    /// "2L · Every day", "1h · Mon, Wed, Fri", "Prayer time".
    private func summary(of slot: RoutineSlot) -> String {
        let schedule = slot.prayer == nil ? slot.effectiveSchedule.label : "Prayer time"
        return [slot.detailText, schedule].compactMap { $0 }.joined(separator: " · ")
    }

    private func relocate() {
        isRelocating = true
        Task {
            if let place = try? await locator.fetchPlace(), var settings = routine.prayerSettings {
                settings.latitude = place.coordinate.latitude
                settings.longitude = place.coordinate.longitude
                settings.placeName = place.name
                routine.prayerSettings = settings
            }
            isRelocating = false
        }
    }

    private func save() {
        Haptics.success()
        store.save(cleaned)
        onFinish()
    }
}
