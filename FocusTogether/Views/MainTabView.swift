import SwiftUI

enum MainTab: Hashable {
    case today, lock, friends
}

/// Three sections — Today, Lock (centre, the main one) and Friends — under a custom tab bar.
struct MainTabView: View {
    @State private var tab: MainTab = .lock
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var avatars: AvatarStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var blocking: BlockingManager
    /// The highest rank we've already celebrated (-1 until the first launch records it).
    @AppStorage("lockin.celebratedRank") private var celebratedRank = -1
    @State private var rankUp: FocusRank?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // A VStack (not safeAreaInset) so each tab's own bottom insets sit above the bar.
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .today: TodayView()
                case .lock: LockView()
                case .friends: FriendsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LockinTabBar(selection: $tab)
        }
        // A lock-in asked for from a widget, the lock screen or Control Center.
        .onOpenURL { url in
            guard url.scheme == "lockin", url.host == "lock",
                  let mode = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "mode" })?.value
            else { return }
            startFromOutside(mode)
        }
        .onAppear { if let mode = LockRequest.take() { startFromOutside(mode) } }
        .onChange(of: scenePhase) { phase in
            if phase == .active, let mode = LockRequest.take() { startFromOutside(mode) }
        }
        // Celebrate a new rank, once the session celebration (if any) is out of the way.
        .onAppear { checkRankUp() }
        .onChange(of: history.totalMinutes) { _ in checkRankUp() }
        .onChange(of: blocking.completedSession?.id) { _ in checkRankUp() }
        .fullScreenCover(item: $rankUp) { RankUpView(rank: $0) }
        // Load a friend's photo as soon as they set or change it.
        .onChange(of: social.friends.map(\.avatarPath)) { _ in
            Task { await avatars.sync(me: social.me, friends: social.friends) }
        }
        .onChange(of: social.me?.avatarPath) { _ in
            Task { await avatars.sync(me: social.me, friends: social.friends) }
        }
        // Keep requests, invites, group sessions and friends' status fresh while the app is open.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await social.refresh()
                await social.publishCurrent()
                await avatars.sync(me: social.me, friends: social.friends)
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }
}

extension MainTabView {
    /// Starts a session straight away; with no apps chosen yet it just shows the Lock tab so you can pick some.
    fileprivate func startFromOutside(_ mode: String) {
        LockLog.add("app handling request mode=\(mode)")
        tab = .lock
        guard blocking.activeSession == nil, blocking.hasSelection else { return }
        Haptics.success()
        blocking.startFromRequest(mode)
    }

    fileprivate func checkRankUp() {
        let current = FocusRank.rank(forMinutes: history.totalMinutes)
        guard celebratedRank >= 0 else {
            // First run with ranks: start from where you are, no fanfare for old progress.
            celebratedRank = current.rawValue
            return
        }
        guard current.rawValue > celebratedRank, blocking.completedSession == nil, rankUp == nil else { return }
        celebratedRank = current.rawValue
        rankUp = current
    }
}

private struct LockinTabBar: View {
    @Binding var selection: MainTab
    @EnvironmentObject private var blocking: BlockingManager
    @EnvironmentObject private var social: SocialStore

    var body: some View {
        HStack(alignment: .center) {
            item(.today, symbol: "checklist", title: "Today")
            lockButton
            item(.friends, symbol: "person.2", title: "Friends", badge: social.pendingCount)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(.bar)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
    }

    private func item(_ tab: MainTab, symbol: String, title: String, badge: Int = 0) -> some View {
        let isSelected = selection == tab
        return Button {
            select(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .frame(height: 24)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Theme.accent, in: Capsule())
                                .offset(x: 12, y: -6)
                        }
                    }
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var lockButton: some View {
        let isLocked = blocking.activeSession != nil
        let isSelected = selection == .lock
        return Button {
            select(.lock)
        } label: {
            ZStack {
                // A concrete UIColor: `Color.primary` turns grey (vibrant) on the bar's material.
                Circle()
                    .fill(Color(uiColor: .label))
                    .frame(width: 58, height: 58)
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.background)
            }
            .overlay(
                Circle()
                    .stroke(Theme.accent, lineWidth: 3)
                    .padding(-5)
                    .opacity(isLocked ? 1 : 0)
            )
            .scaleEffect(isSelected ? 1 : 0.9)
            .animation(Theme.spring, value: isSelected)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLocked ? "Lock, session running" : "Lock")
    }

    private func select(_ tab: MainTab) {
        guard selection != tab else { return }
        Haptics.select()
        selection = tab
    }
}
