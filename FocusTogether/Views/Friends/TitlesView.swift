import SwiftUI

/// Your title: the rank you've earned this week, the ones still locked, or words of your own.
struct TitlesView: View {
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var useOwn = false
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var minutes: Int { history.weekMinutes }
    private var current: FocusRank { .rank(forMinutes: minutes) }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PillPicker(options: [false, true], selection: $useOwn) { $0 ? "My own words" : "My rank" }

                    if useOwn { ownTitle } else { ranks }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: useOwn)
            }
            .navigationTitle("Your title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(isSaving || (useOwn && trimmed.isEmpty))
                }
            }
            .onAppear {
                text = social.me?.profileTitle ?? ""
                useOwn = !(social.me?.profileTitle ?? "").isEmpty
            }
            .alert("Title", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
        .presentationDetents([.large])
    }

    // MARK: Ranks

    private var ranks: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ranks are earned from your focus time this week, Monday to Sunday, and start again each week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let next = current.next {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressBar(progress: min(1, Double(minutes) / Double(next.minutes)))
                            .frame(height: 8)
                        Text("\(minutes.minutesLabel) so far · \(max(0, next.minutes - minutes).minutesLabel) to \(next.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 6)
                }
            }

            VStack(spacing: 10) {
                ForEach(FocusRank.allCases) { rank in
                    rankRow(rank)
                }
            }
        }
    }

    private func rankRow(_ rank: FocusRank) -> some View {
        let unlocked = minutes >= rank.minutes
        let isCurrent = rank == current
        return HStack(spacing: 14) {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(unlocked ? Theme.accent : Color.secondary)
                .frame(width: 40, height: 40)
                .background((unlocked ? Theme.accent : Color.primary).opacity(unlocked ? 0.14 : 0.06), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(rank.title)
                        .font(.subheadline.weight(.semibold))
                    if isCurrent {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                Text(unlocked ? rank.requirement : "\(rank.requirement) · \(max(0, rank.minutes - minutes).minutesLabel) to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.accent, lineWidth: isCurrent ? 1.5 : 0))
        .opacity(unlocked ? 1 : 0.7)
    }

    // MARK: Own words

    private var ownTitle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Write anything you like. It shows on your card instead of your rank, and your friends see it too.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Med student, Gym rat, Night owl…", text: $text)
                .focused($isFocused)
                .submitLabel(.done)
                .onChange(of: text) { text = String($0.prefix(24)) }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("\(text.count)/24")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onAppear { isFocused = true }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await social.setCustomTitle(useOwn ? trimmed : nil)
                Haptics.success()
                dismiss()
            } catch {
                errorMessage = "Couldn't save your title. Check your connection."
            }
            isSaving = false
        }
    }
}
