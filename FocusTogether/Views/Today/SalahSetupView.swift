import Adhan
import SwiftUI

/// Finds the user's city once and previews today's Salah times before adding the routine.
struct SalahSetupView: View {
    let onAdd: (Routine) -> Void

    @State private var locator = LocationFetcher()
    @State private var settings: PrayerSettings?
    @State private var reminderMinutes: Int? = 10
    @State private var isLocating = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Salah times")
                        .font(.title2.bold())
                    Text("Lockin can use your location to show accurate times for each prayer. It's only used on this phone to calculate them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let settings {
                    PrayerSettingsCard(settings: Binding(
                        get: { settings },
                        set: { self.settings = $0 }
                    ))

                    HStack {
                        Label("Reminder", systemImage: "bell")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        PrayerReminderPicker(minutes: $reminderMinutes)
                    }
                    .card(padding: 14)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.gutter)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if settings == nil {
                    Button(action: locate) {
                        if isLocating {
                            ProgressView().tint(Theme.background)
                        } else {
                            Label("Use my location", systemImage: "location.fill")
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(isLocating)

                    Button("Skip — just track the prayers") {
                        onAdd(RoutineDrafts.salah(settings: nil))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                } else {
                    Button("Add Salah") {
                        Haptics.success()
                        var routine = RoutineDrafts.salah(settings: settings)
                        routine.prayerReminderMinutes = reminderMinutes
                        Task {
                            // Ask before adding, so the first reminders can be scheduled straight away.
                            if reminderMinutes != nil { await ReminderScheduler.requestPermission() }
                            onAdd(routine)
                        }
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding(Theme.gutter)
            .background(Theme.background)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func locate() {
        isLocating = true
        errorMessage = nil
        Task {
            do {
                let place = try await locator.fetchPlace()
                withAnimation(Theme.spring) {
                    settings = PrayerSettings(
                        latitude: place.coordinate.latitude,
                        longitude: place.coordinate.longitude,
                        placeName: place.name,
                        method: PrayerCalculator.suggestedMethod(forCountryCode: place.countryCode),
                        hanafiAsr: false
                    )
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't find your location. Try again, or skip to track the prayers without times."
            }
            isLocating = false
        }
    }
}

/// "Remind me" for Salah: off, at prayer time, or a few minutes before.
struct PrayerReminderPicker: View {
    @Binding var minutes: Int?

    var body: some View {
        Picker("Remind me", selection: $minutes) {
            Text("Off").tag(Int?.none)
            Text("At prayer time").tag(Int?.some(0))
            ForEach([5, 10, 15, 30], id: \.self) { value in
                Text("\(value) min before").tag(Int?.some(value))
            }
        }
        .pickerStyle(.menu)
        .tint(.primary)
    }
}

/// Place, today's times, calculation method and Asr setting. Shared by setup and the editor.
struct PrayerSettingsCard: View {
    @Binding var settings: PrayerSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(settings.placeName, systemImage: "location.fill")
                .font(.headline)

            let times = PrayerCalculator.times(for: settings, on: .now)
            HStack(spacing: 0) {
                ForEach(PrayerName.allCases, id: \.self) { prayer in
                    VStack(spacing: 4) {
                        Text(prayer.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(times[prayer].map { $0.formatted(date: .omitted, time: .shortened) } ?? "–")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()

            Picker("Calculation", selection: $settings.method) {
                ForEach(PrayerCalculator.methods, id: \.self) { method in
                    Text(PrayerCalculator.name(of: method)).tag(method)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)

            Toggle("Hanafi Asr (later)", isOn: $settings.hanafiAsr)
                .tint(Theme.accent)
        }
        .font(.subheadline)
        .card(padding: 18)
    }
}
