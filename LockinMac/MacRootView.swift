import SwiftUI

enum MacSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case plan = "Plan"
    case focus = "Focus"
    case profile = "Profile"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: "checklist"
        case .plan: "calendar"
        case .focus: "lock.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

/// A see-through window: a frosted sidebar on the left and a roomy detail pane on the right.
struct MacRootView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var focus: MacFocus
    @State private var section: MacSection = .today

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 270)
            ZStack {
                backdrop
                detail
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image("LogoDark")
                    .resizable().scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Lockin")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            .padding(.top, 54)
            .padding(.bottom, 26)

            ForEach(MacSection.allCases) { item in
                sidebarRow(item)
            }

            Spacer()

            sidebarCard
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.55))
    }

    private func sidebarRow(_ item: MacSection) -> some View {
        let isSelected = section == item
        return Button {
            withAnimation(Theme.spring) { section = item }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 26)
                Text(item.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.60, blue: 0.30), Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: isSelected ? Theme.accent.opacity(0.35) : .clear, radius: 10, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Your rank and numbers, tidy and fixed-size.
    private var sidebarCard: some View {
        let rank = FocusRank.rank(forMinutes: history.totalMinutes)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RankBadge(rank: rank, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rank.title).font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("\(history.totalMinutes / 60) hours locked in")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 0) {
                miniStat(history.todayMinutes.minutesLabel, "today")
                miniStat(history.weekMinutes.minutesLabel, "week")
                miniStat("\(history.streakDays)", "streak", flame: true)
            }
        }
        .glassCard(padding: 16, radius: 22)
    }

    private func miniStat(_ value: String, _ label: String, flame: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                if flame { Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(Theme.accent) }
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
            }
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Detail

    private var detail: some View {
        Group {
            switch section {
            case .today: MacTodayView()
            case .plan: MacPlanView()
            case .focus: MacFocusView()
            case .profile: MacProfileView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Slow colour behind the glass, so the cards have something to be glass over.
    private var backdrop: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                blob(Theme.accent, 0.30, 640, x: 280 + 60 * sin(t * 0.21), y: -230 + 50 * cos(t * 0.17))
                blob(Color(red: 0.55, green: 0.38, blue: 0.95), 0.24, 560, x: -260 + 70 * cos(t * 0.19), y: 250 + 60 * sin(t * 0.23))
                blob(Color(red: 0.20, green: 0.60, blue: 0.95), 0.16, 480, x: 140 + 80 * sin(t * 0.15), y: 300 + 40 * cos(t * 0.2))
            }
        }
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, _ opacity: Double, _ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(color.opacity(opacity)).frame(width: size, height: size).blur(radius: 120).offset(x: x, y: y)
    }
}
