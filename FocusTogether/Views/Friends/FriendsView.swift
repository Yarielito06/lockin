import SwiftUI

/// The third tab: your stats, who's locked in right now, and this week's leaderboard.
struct FriendsView: View {
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @State private var isAddingFriend = false
    @State private var isShowingMyCard = false
    @State private var selectedFriend: Friend?
    @State private var section: FriendsSection = .moments
    @EnvironmentObject private var moments: MomentsStore

    private enum FriendsSection: String, CaseIterable {
        case moments = "Moments"
        case ranks = "This week"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(title: "Friends") {
                        CircleIconButton(systemName: "person.badge.plus", accessibilityLabel: "Add friend") {
                            isAddingFriend = true
                        }
                    }

                    if social.needsName {
                        NameSetupCard()
                    } else {
                        meCard
                    }

                    PendingSection()

                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let focusing = social.friendsFocusing(at: context.date)
                        if !focusing.isEmpty {
                            lockedInNow(focusing, now: context.date)
                        }
                    }

                    if social.isOnline, !social.needsName {
                        PillPicker(options: FriendsSection.allCases, selection: $section) { $0.rawValue }
                        if section == .moments {
                            MomentsFeed()
                        } else {
                            leaderboard
                        }
                    } else {
                        leaderboard
                    }

                    if social.isOnline, !social.needsName, social.friends.isEmpty {
                        Text("No friends yet. Tap the button at the top to share your code.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }

                    if social.hasSampleFriends {
                        Text("These are sample friends. Real friends appear once sync is set up.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await social.refresh()
                await moments.refresh()
            }
            .task { await social.refresh() }
            .sheet(isPresented: $isAddingFriend) { AddFriendView() }
            .sheet(isPresented: $isShowingMyCard) { MyProfileView() }
            .sheet(item: $selectedFriend) { FriendDetailView(friend: $0) }
            .alert(
                "Friends",
                isPresented: Binding(get: { social.errorMessage != nil }, set: { if !$0 { social.errorMessage = nil } }),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(social.errorMessage ?? "") }
            )
        }
    }

    // MARK: Sections

    private var meCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Avatar(name: social.me?.displayName ?? "You", size: 44, isMe: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You").font(.headline)
                    Text(social.me.map { "\($0.displayName) · \($0.inviteCode)" }
                        ?? (history.streakDays > 0 ? "On a \(history.streakDays)-day streak" : "Lock in today to start a streak"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if social.me != nil {
                    Label("My card", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }
            }
            HStack(spacing: 0) {
                stat(history.todayMinutes.minutesLabel, "Today")
                Divider().frame(height: 32)
                stat(history.weekMinutes.minutesLabel, "This week")
                Divider().frame(height: 32)
                stat("\(history.streakDays)", "Day streak", symbol: "flame.fill", lit: history.streakDays > 0)
            }
        }
        .card(padding: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            guard social.me != nil else { return }
            Haptics.tap()
            isShowingMyCard = true
        }
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

    private func lockedInNow(_ friends: [Friend], now: Date) -> some View {
        VStack(spacing: 12) {
            SectionTitle("Locked in now")
            VStack(spacing: 0) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 { Divider().padding(.leading, 56) }
                    HStack(spacing: 12) {
                        Avatar(name: friend.name, size: 40)
                            .overlay(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.name).font(.subheadline.weight(.semibold))
                            Text(friend.focusStatus(at: now))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if friend.isSample {
                            Image(systemName: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.accent)
                        } else {
                            CheerMenu(friend: friend)
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFriend = friend }
                }
            }
            .card(padding: 14)
        }
    }

    private var leaderboard: some View {
        let entries = leaderboardEntries
        let best = max(1, entries.first?.minutes ?? 1)
        return VStack(spacing: 12) {
            HStack {
                SectionTitle("This week")
                Text("Focus time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider().padding(.leading, 76) }
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(index == 0 ? Theme.accent : .secondary)
                            .frame(width: 18)
                        Avatar(name: entry.isMe ? (social.me?.displayName ?? "You") : entry.name, size: 36, isMe: entry.isMe)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(entry.isMe ? "You" : entry.name)
                                    .font(.subheadline.weight(entry.isMe ? .bold : .medium))
                                    .lineLimit(1)
                                Spacer()
                                if entry.streak > 0 {
                                    Label("\(entry.streak)", systemImage: "flame.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                        .labelStyle(.titleAndIcon)
                                }
                                Text(entry.minutes.minutesLabel)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 52, alignment: .trailing)
                            }
                            ProgressBar(
                                progress: Double(entry.minutes) / Double(best),
                                tint: entry.isMe ? Theme.accent : Color.primary.opacity(0.75)
                            )
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let friend = entry.friend { selectedFriend = friend }
                    }
                    .accessibilityAddTraits(entry.friend != nil ? .isButton : [])
                    .accessibilityHint(entry.friend != nil ? "Shows their profile and Remove friend" : "")
                }
            }
            .card(padding: 14)
        }
    }

    // MARK: Data

    private struct Entry: Identifiable {
        let id: UUID
        let name: String
        let minutes: Int
        let streak: Int
        let isMe: Bool
        let friend: Friend?
    }

    private static let meID = UUID()

    private var leaderboardEntries: [Entry] {
        let me = Entry(id: Self.meID, name: "You", minutes: history.weekMinutes, streak: history.streakDays, isMe: true, friend: nil)
        let friends = social.friends.map {
            Entry(id: $0.id, name: $0.name, minutes: $0.weekMinutes, streak: $0.streak, isMe: false, friend: $0)
        }
        return ([me] + friends).sorted { $0.minutes > $1.minutes }
    }
}
