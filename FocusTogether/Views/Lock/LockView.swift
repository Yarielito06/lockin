import SwiftUI

/// The centre tab: set up a session, or follow the one that's running.
struct LockView: View {
    @EnvironmentObject private var blocking: BlockingManager

    var body: some View {
        ZStack {
            if let session = blocking.activeSession {
                CountdownView(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LockSetupView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.spring, value: blocking.activeSession?.id)
    }
}

private enum LockMode: String, CaseIterable {
    case solo = "Solo"
    case group = "Group"
}

private struct LockSetupView: View {
    @EnvironmentObject private var blocking: BlockingManager
    @EnvironmentObject private var social: SocialStore

    @State private var mode: LockMode = .solo
    @State private var duration: FocusDuration = .pomodoro
    /// Free time (no fixed length) is the default for solo sessions.
    @State private var isFreeTime = true
    @State private var selectedGroupID: UUID?
    @State private var isCreatingGroup = false

    private var selectedGroup: StudyGroup? {
        social.groups.first { $0.id == selectedGroupID }
    }

    private var canStart: Bool {
        blocking.hasSelection && (mode == .solo || selectedGroup != nil)
    }

    private var hint: String? {
        if !blocking.hasSelection { return "Choose the apps to block first." }
        if mode == .group && selectedGroup == nil { return "Pick or create a group." }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ScreenHeader(title: "Lock in")

                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if let group = social.joinableGroupSession(at: context.date) {
                            JoinGroupSessionCard(group: group, now: context.date)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    PillPicker(options: LockMode.allCases, selection: $mode) { $0.rawValue }

                    durationPicker

                    if mode == .group {
                        groupSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    AppSelectionView()
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 16)
                .animation(Theme.spring, value: mode)
            }
            .safeAreaInset(edge: .bottom) { startButton }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isCreatingGroup) {
                NewGroupView { group in selectedGroupID = group.id }
            }
            .onChange(of: mode) { newMode in
                if newMode == .group, selectedGroup == nil {
                    selectedGroupID = social.groups.first?.id
                }
            }
        }
    }

    private var usesFreeTime: Bool { isFreeTime && mode == .solo }

    private var durationPicker: some View {
        VStack(spacing: 20) {
            VStack(spacing: 0) {
                Text(usesFreeTime ? "∞" : "\(duration.minutes)")
                    .font(.system(size: 104, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(usesFreeTime ? "until you stop" : "minutes")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if mode == .solo {
                    ChipButton(title: "Free", isSelected: isFreeTime) {
                        Haptics.select()
                        withAnimation(Theme.spring) { isFreeTime = true }
                    }
                }
                ForEach(FocusDuration.options) { option in
                    ChipButton(title: "\(option.minutes)", isSelected: !usesFreeTime && option == duration) {
                        Haptics.select()
                        withAnimation(Theme.spring) {
                            isFreeTime = false
                            duration = option
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var groupSection: some View {
        VStack(spacing: 12) {
            HStack {
                SectionTitle("Lock in with")
                Button("New group") { isCreatingGroup = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            if social.groups.isEmpty {
                Button { isCreatingGroup = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3")
                            .font(.title2)
                        Text("Create your first group")
                            .font(.subheadline.weight(.semibold))
                        Text("Study, work or pray together.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(social.groups) { group in
                            GroupCard(
                                group: group,
                                memberNames: social.members(of: group).map(\.name),
                                invitedCount: social.invitedMembers(of: group).count,
                                isSelected: group.id == selectedGroupID
                            ) {
                                Haptics.select()
                                selectedGroupID = group.id
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    social.delete(group)
                                    if selectedGroupID == group.id { selectedGroupID = nil }
                                } label: {
                                    Label(social.isOnline ? "Leave group" : "Delete group", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        }
                    }
                    .padding(2)
                }
            }
        }
    }

    private var startButton: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.success()
                let group = mode == .group ? selectedGroup : nil
                if usesFreeTime {
                    blocking.startOpenEndedSession()
                } else {
                    blocking.startSession(minutes: duration.minutes, groupName: group?.name)
                }
                if let group, let session = blocking.activeSession {
                    Task { await social.announceGroupSession(group, endsAt: session.endDate) }
                }
            } label: {
                Label("Lock in", systemImage: "lock.fill")
            }
            .buttonStyle(.primary)
            .disabled(!canStart)

            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
        .background(alignment: .top) {
            // Soft fade so content scrolling underneath doesn't end in a hard edge.
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
                .offset(y: -28)
                .allowsHitTesting(false)
        }
    }
}

private struct GroupCard: View {
    let group: StudyGroup
    let memberNames: [String]
    let invitedCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                AvatarStack(names: memberNames.isEmpty ? [group.name] : memberNames)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(invitedCount > 0
                         ? "\(memberNames.count + 1) in · \(invitedCount) invited"
                         : "\(memberNames.count + 1) people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(width: 150, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "Library crew is locking in" — a group lock-in someone else started, with a Join button.
/// Joining blocks your own apps until the same end time; nobody can lock anyone else's phone.
private struct JoinGroupSessionCard: View {
    let group: StudyGroup
    let now: Date

    @EnvironmentObject private var blocking: BlockingManager
    @EnvironmentObject private var social: SocialStore

    private var minutesLeft: Int {
        Int(((group.sessionEndsAt ?? now).timeIntervalSince(now) / 60).rounded(.up))
    }

    private var canJoin: Bool {
        (group.sessionEndsAt ?? now).timeIntervalSince(now) >= BlockingManager.minimumSessionLength
    }

    private var lockedInNames: [String] {
        social.members(of: group).filter { $0.isFocusing(at: now) }.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text("\(group.name) is locking in")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(Theme.spring) { social.dismissGroupSession(group) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Not now")
            }

            HStack(spacing: 10) {
                if !lockedInNames.isEmpty {
                    AvatarStack(names: lockedInNames, size: 28, ringColor: Theme.surface)
                }
                Text("\(group.sessionStartedByName ?? "Someone") started · \(minutesLeft) min left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Haptics.success()
                if let endsAt = group.sessionEndsAt {
                    blocking.joinSession(until: endsAt, groupName: group.name)
                }
            } label: {
                Label(canJoin ? "Join" : "Too late to join (under 15 min)", systemImage: "lock.fill")
            }
            .buttonStyle(.primary)
            .disabled(!canJoin || !blocking.hasSelection)

            if !blocking.hasSelection {
                Text("Choose your blocked apps below first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 18)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1.5)
        )
    }
}
