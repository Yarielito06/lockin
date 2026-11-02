import SwiftUI

/// Shown while a session is running: a thin progress ring and the time remaining.
struct CountdownView: View {
    let session: FocusSession

    @EnvironmentObject private var blocking: BlockingManager
    @EnvironmentObject private var social: SocialStore
    @State private var isConfirmingEnd = false

    private var groupMembers: [String] {
        guard let name = session.groupName, let group = social.group(named: name) else { return [] }
        return social.members(of: group).map(\.name)
    }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 8) {
                Label("Locked in", systemImage: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                if let groupName = session.groupName {
                    Text("with \(groupName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                if session.isOpenEnded {
                    ZStack {
                        // One lap per hour.
                        ProgressRing(progress: session.elapsed(at: context.date).truncatingRemainder(dividingBy: 3600) / 3600, lineWidth: 6)
                        VStack(spacing: 4) {
                            Text(Self.format(session.elapsed(at: context.date), roundingUp: false))
                                .font(.system(size: 64, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .contentTransition(.numericText())
                            Text("free time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 280, height: 280)
                } else {
                ZStack {
                    ProgressRing(progress: session.progress(at: context.date), lineWidth: 6)
                    VStack(spacing: 4) {
                        Text(Self.format(session.remaining(at: context.date)))
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("of \(session.durationMinutes) min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 280, height: 280)
                }
            }

            CheersStrip(since: session.startDate)

            if !groupMembers.isEmpty {
                HStack(spacing: 10) {
                    AvatarStack(names: groupMembers, size: 32, ringColor: Theme.background)
                    Text("+ you")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if session.isOpenEnded {
                Button {
                    Haptics.success()
                    blocking.stopOpenEndedSession()
                } label: {
                    Label("Stop and unlock", systemImage: "stop.fill")
                }
                .buttonStyle(.primary)
                .padding(.bottom, 4)
            } else {
                Button("End early") { isConfirmingEnd = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                    .confirmationDialog("End this session early?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
                        Button("End and unblock apps", role: .destructive) { blocking.giveUp() }
                    } message: {
                        Text("It won't count towards your streak.")
                    }
            }
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity)
        .task(id: session.id) {
            if session.isOpenEnded {
                // Free time has no end; keep nudging its safety cap forward while the app is open.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                    blocking.refresh()
                }
                return
            }
            // Fire exactly when the session ends; `refresh()` also runs when the app becomes active.
            let remaining = session.remaining(at: .now)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            blocking.refresh()
        }
    }

    private static func format(_ interval: TimeInterval, roundingUp: Bool = true) -> String {
        let total = Int(roundingUp ? interval.rounded(.up) : interval.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
