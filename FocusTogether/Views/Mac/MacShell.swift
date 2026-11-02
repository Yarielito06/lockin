import SwiftUI

/// The Mac layout: a glassy sidebar, a roomy detail pane, and a floating focus island.
struct MacShell: View {
    @Binding var tab: MainTab

    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var avatars: AvatarStore
    @EnvironmentObject private var blocking: BlockingManager

    enum Section: Hashable, CaseIterable {
        case lock, today, calendar, friends

        var title: String {
            switch self {
            case .lock: "Lock in"
            case .today: "Today"
            case .calendar: "Calendar"
            case .friends: "Friends"
            }
        }

        var symbol: String {
            switch self {
            case .lock: "lock.fill"
            case .today: "checklist"
            case .calendar: "calendar"
            case .friends: "person.2.fill"
            }
        }
    }

    @State private var section: Section? = .lock
    @State private var isShowingMyCard = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 340)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $isShowingMyCard) { MyProfileView() }
        .onChange(of: tab) { newTab in
            switch newTab {
            case .lock: section = .lock
            case .today: section = .today
            case .friends: section = .friends
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image("LogoDark")
                    .resizable().scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text("Lockin")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
            .padding(.bottom, 22)

            VStack(spacing: 6) {
                ForEach(Section.allCases, id: \.self) { item in
                    row(item)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 12)

            Button { isShowingMyCard = true } label: {
                MeCardHeader(
                    info: .mine(social: social, history: history, avatars: avatars),
                    todayMinutes: history.todayMinutes,
                    compact: true
                )
            }
            .buttonStyle(.plain)
            .disabled(social.me == nil)
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func row(_ item: Section) -> some View {
        let isSelected = section == item
        return Button {
            Haptics.select()
            withAnimation(Theme.spring) { section = item }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 26)
                Text(item.title)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if item == .friends, social.pendingCount > 0 {
                    Text("\(social.pendingCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.accent, in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.58, blue: 0.28), Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Detail

    private var detail: some View {
        ZStack(alignment: .top) {
            backdrop
            Group {
                switch section ?? .lock {
                case .lock: LockView()
                case .today: TodayView()
                case .calendar: CalendarView()
                case .friends: FriendsView()
                }
            }
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            // Bigger text everywhere on the Mac.
            .environment(\.dynamicTypeSize, .xxLarge)

            FocusIsland()
                .padding(.top, 10)
        }
    }

    private var maxWidth: CGFloat {
        switch section ?? .lock {
        case .today: 1240
        case .lock: 760
        case .calendar: 980
        case .friends: 1000
        }
    }

    /// Soft colour behind frosted cards, so the glass has something to be glass over.
    private var backdrop: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.background
                blob(Theme.accent, 0.38, 640, x: 330 + 60 * sin(t * 0.21), y: -260 + 50 * cos(t * 0.17))
                blob(Color(red: 0.55, green: 0.38, blue: 0.95), 0.30, 560, x: -340 + 70 * cos(t * 0.19), y: 280 + 60 * sin(t * 0.23))
                blob(Color(red: 0.20, green: 0.60, blue: 0.95), 0.22, 480, x: 120 + 80 * sin(t * 0.15), y: 330 + 40 * cos(t * 0.2))
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, _ opacity: Double, _ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(color.opacity(opacity)).frame(width: size, height: size).blur(radius: 120).offset(x: x, y: y)
    }
}

// MARK: - Focus island

/// A floating pill at the top while you're locked in: a live timer you can tap to open and stop.
struct FocusIsland: View {
    @EnvironmentObject private var blocking: BlockingManager
    @State private var isExpanded = false
    @State private var pulse = false
    @State private var isConfirmingEnd = false

    var body: some View {
        Group {
            if let session = blocking.activeSession {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    island(session, now: context.date)
                }
                .transition(.move(edge: .top).combined(with: .scale(scale: 0.6, anchor: .top)).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: blocking.activeSession?.id)
    }

    private func island(_ session: FocusSession, now: Date) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 10, height: 10)
                .shadow(color: Theme.accent.opacity(0.8), radius: pulse ? 8 : 2)
                .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true } }

            Text(session.isOpenEnded ? Self.format(session.elapsed(at: now)) : Self.format(session.remaining(at: now)))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            if isExpanded {
                Text(session.isOpenEnded ? "free time" : (session.groupName.map { "with \($0)" } ?? "locked in"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .transition(.opacity)
                Button {
                    if session.isOpenEnded {
                        Haptics.success()
                        blocking.stopOpenEndedSession()
                    } else {
                        isConfirmingEnd = true
                    }
                } label: {
                    Text(session.isOpenEnded ? "Stop" : "End")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Color.black, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .onTapGesture {
            Haptics.tap()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { isExpanded.toggle() }
        }
        .confirmationDialog("End this session early?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) { blocking.giveUp() }
        } message: {
            Text("It won't count towards your streak.")
        }
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
}
