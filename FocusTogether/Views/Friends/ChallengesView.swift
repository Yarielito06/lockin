import SwiftUI

/// This week's group challenges, on the Friends tab.
struct ChallengesSection: View {
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @State private var isCreating = false

    var body: some View {
        if social.isOnline, !social.needsName, !(social.groups.isEmpty && social.challenges.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle("Challenges")
                    Button { isCreating = true } label: {
                        Label("New", systemImage: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                    }
                }
                if social.challenges.isEmpty {
                    Button { isCreating = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 46, height: 46)
                                .background(Theme.accent.opacity(0.14), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start a challenge").font(.headline)
                                Text("Set a shared goal for your group this week — like 20 hours together.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .foregroundStyle(.primary)
                        .card(padding: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(social.challenges) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }
            }
            .sheet(isPresented: $isCreating) { NewChallengeView() }
        }
    }
}

private struct ChallengeCard: View {
    let challenge: GroupChallenge

    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @State private var isConfirmingEnd = false

    private var me: UUID? { social.me?.id }
    private var total: Int { challenge.totalMinutes(me: me, myMinutes: history.weekMinutes) }
    private var fraction: Double { challenge.fraction(me: me, myMinutes: history.weekMinutes) }
    private var isDone: Bool { fraction >= 1 }

    private var daysLeft: Int {
        let calendar = Calendar(identifier: .iso8601)
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? .now
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: end).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: isDone ? "trophy.fill" : "target")
                            .foregroundStyle(Theme.accent)
                        Text(challenge.title).font(.headline).lineLimit(1)
                    }
                    Text("\(challenge.groupName) · \(isDone ? "Complete!" : "\(daysLeft) \(daysLeft == 1 ? "day" : "days") left")")
                        .font(.caption)
                        .foregroundStyle(isDone ? Theme.accent : Color.secondary)
                }
                Spacer()
                Menu {
                    Button(role: .destructive) { isConfirmingEnd = true } label: { Label("End challenge", systemImage: "xmark.circle") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(total.minutesLabel)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \((challenge.targetMinutes).minutesLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
                ProgressBar(progress: fraction).frame(height: 10)
            }

            VStack(spacing: 8) {
                ForEach(challenge.members.sorted { minutes(of: $0) > minutes(of: $1) }) { member in
                    HStack(spacing: 10) {
                        Avatar(name: member.name, size: 28, isMe: member.id == me, userID: member.id)
                        Text(member.id == me ? "You" : member.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(minutes(of: member).minutesLabel)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card(padding: 18)
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.accent.opacity(isDone ? 0.7 : 0), lineWidth: 1.5))
        .animation(Theme.spring, value: total)
        .confirmationDialog("End this challenge?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End for everyone", role: .destructive) { Task { await social.endChallenge(challenge) } }
        }
    }

    private func minutes(of member: GroupChallenge.Member) -> Int {
        member.id == me ? max(member.minutes, history.weekMinutes) : member.minutes
    }
}

/// Pick a group, name the challenge and set the hours.
struct NewChallengeView: View {
    @EnvironmentObject private var social: SocialStore
    @Environment(\.dismiss) private var dismiss

    @State private var groupID: UUID?
    @State private var title = ""
    @State private var hours = 10
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let ideas = ["Study marathon", "Gym week", "Deep work", "Early birds"]
    private let hourOptions = [5, 10, 20, 30, 50]
    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var group: StudyGroup? { social.groups.first { $0.id == groupID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        if social.groups.isEmpty {
                            Text("Create a group in the Lock in tab first, then set it a challenge.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(social.groups) { option in
                                        ChipButton(title: option.name, isSelected: option.id == groupID) {
                                            Haptics.select()
                                            groupID = option.id
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name it").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("Study marathon", text: $title)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onChange(of: title) { title = String($0.prefix(40)) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ideas, id: \.self) { idea in
                                    Button { title = idea } label: {
                                        Text(idea)
                                            .font(.footnote.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Theme.surface, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Together this week").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text("\(hours) hours")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        HStack(spacing: 8) {
                            ForEach(hourOptions, id: \.self) { option in
                                ChipButton(title: "\(option)h", isSelected: option == hours) {
                                    Haptics.select()
                                    withAnimation(Theme.spring) { hours = option }
                                }
                            }
                        }
                        Text("Everyone's focus time this week counts. It resets next Monday.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }

                    Button {
                        start()
                    } label: {
                        if isSaving { ProgressView().tint(Theme.background) } else { Label("Start challenge", systemImage: "trophy.fill") }
                    }
                    .buttonStyle(.primary)
                    .disabled(group == nil || trimmed.isEmpty || isSaving)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .navigationTitle("New challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { groupID = social.groups.first?.id }
        }
        .presentationDetents([.large])
    }

    private func start() {
        guard let group else { return }
        isSaving = true
        Task {
            let error = await social.startChallenge(in: group, title: trimmed, hours: hours)
            isSaving = false
            if let error {
                errorMessage = error
            } else {
                Haptics.success()
                dismiss()
            }
        }
    }
}
