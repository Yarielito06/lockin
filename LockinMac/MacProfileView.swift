import SwiftUI

/// Your rank, your numbers and the road to the next badge.
struct MacProfileView: View {
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let total = history.totalMinutes
        let rank = FocusRank.rank(forMinutes: total)
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Profile").font(.system(size: 40, weight: .bold, design: .rounded))

                HStack(spacing: 26) {
                    VStack(spacing: 14) {
                        RankBadge(rank: rank, size: 120)
                        Text(rank.title).font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("\(total / 60) hours locked in").font(.system(size: 15)).foregroundStyle(.secondary)
                        if let next = rank.next {
                            VStack(spacing: 6) {
                                ProgressView(value: Double(total - rank.minutes), total: Double(max(1, next.minutes - rank.minutes))).tint(Theme.accent)
                                Text("\((next.minutes - total).minutesLabel) to \(next.title)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent)
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .glassCard(padding: 20, radius: 34)

                    VStack(spacing: 16) {
                        bigStat(history.todayMinutes.minutesLabel, "focused today", "sun.max.fill")
                        bigStat(history.weekMinutes.minutesLabel, "this week", "calendar")
                        bigStat("\(history.streakDays)", "day streak", "flame.fill")
                    }
                    .frame(width: 330)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ranks").font(.system(size: 20, weight: .bold, design: .rounded))
                    ForEach(FocusRank.allCases) { item in
                        let unlocked = total >= item.minutes
                        HStack(spacing: 14) {
                            RankBadge(rank: item, size: 36).saturation(unlocked ? 1 : 0).opacity(unlocked ? 1 : 0.45)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.system(size: 16, weight: .semibold))
                                Text(item.minutes == 0 ? "Where everyone begins" : "Lock in for \(item.minutes / 60) hours in total")
                                    .font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if unlocked { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent) }
                            else { Image(systemName: "lock.fill").foregroundStyle(.tertiary) }
                        }
                    }
                }
                .glassCard(padding: 22, radius: 28)

                Text("Friends, cheers and Moments are on your iPhone for now. They're coming to the Mac next.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.top, 54)
            .padding(.bottom, 40)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }

    private func bigStat(_ value: String, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.accent)
                .frame(width: 50, height: 50).background(Theme.accent.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .glassCard(padding: 18, radius: 26)
    }
}
