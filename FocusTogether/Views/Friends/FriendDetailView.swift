import SwiftUI

/// A friend's card: live status, this week's focus and streak, and Remove friend.
struct FriendDetailView: View {
    let friend: Friend

    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var avatars: AvatarStore
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemove = false

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 22) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(spacing: 14) {
                        ProfileCard(
                            info: ProfileCardInfo(
                                name: friend.name,
                                isLockedIn: friend.isFocusing(at: context.date),
                                weekMinutes: friend.weekMinutes,
                                streak: friend.streak,
                                avatar: avatars.image(for: friend.id)
                            ),
                            style: .dark
                        )
                        .shadow(color: Color(red: 1, green: 0.42, blue: 0.18).opacity(0.3), radius: 22, y: 10)

                        if friend.isFocusing(at: context.date) {
                            Label("Locked in · \(friend.focusStatus(at: context.date))", systemImage: "lock.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.accent)
                            if !friend.isSample { CheerMenu(friend: friend, style: .large) }
                        }
                    }
                }

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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
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
