import SwiftUI

enum MainTab: Hashable {
    case today, lock, friends
}

/// Three sections — Today, Lock (centre, the main one) and Friends — under a custom tab bar.
struct MainTabView: View {
    @State private var tab: MainTab = .lock
    @EnvironmentObject private var social: SocialStore
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
        // Keep requests, invites, group sessions and friends' status fresh while the app is open.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await social.refresh()
                await social.publishCurrent()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
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
