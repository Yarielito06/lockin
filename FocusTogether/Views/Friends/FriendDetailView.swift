import SwiftUI

/// A friend's card: live status, this week's focus and streak, and Remove friend.
struct FriendDetailView: View {
    let friend: Friend

    @EnvironmentObject private var social: SocialStore
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemove = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Avatar(name: friend.name, size: 84)
                    Text(friend.name)
                        .font(.title2.bold())
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if friend.isFocusing(at: context.date) {
                            Label("Locked in · \(friend.focusStatus(at: context.date))", systemImage: "lock.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                        } else {
                            Text("Not locked in right now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                HStack(spacing: 0) {
                    stat(friend.weekMinutes.minutesLabel, "This week")
                    Divider().frame(height: 32)
                    stat("\(friend.streak)", "Day streak", symbol: "flame.fill", lit: friend.streak > 0)
                }
                .card(padding: 18)

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    if friend.isFocusing(at: context.date), !friend.isSample {
                        CheerMenu(friend: friend, style: .large)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    isConfirmingRemove = true
                } label: {
                    Label("Remove friend", systemImage: "person.badge.minus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.red.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .confirmationDialog(
                    "Remove \(friend.name)?",
                    isPresented: $isConfirmingRemove,
                    titleVisibility: .visible
                ) {
                    Button("Remove friend", role: .destructive) {
                        Haptics.tap()
                        social.remove(friend)
                        dismiss()
                    }
                } message: {
                    Text("You'll stop seeing each other's focus. You can add each other again any time.")
                }
            }
            .padding(Theme.gutter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func stat(_ value: String, _ label: String, symbol: String? = nil, lit: Bool = true) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.subheadline)
                        .foregroundStyle(lit ? Theme.accent : Color.secondary)
                }
                Text(value)
                    .font(.title3.bold().monospacedDigit())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
