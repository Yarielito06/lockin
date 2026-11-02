import SwiftUI
import WidgetKit

// MARK: - Provider

/// Entries at the moments content changes by itself: each friend's lock-in ending, and midnight.
struct SocialProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockinEntry {
        LockinEntry(date: .now, snapshot: .socialPreview, isPreview: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockinEntry) -> Void) {
        completion(LockinEntry(date: .now, snapshot: context.isPreview ? .socialPreview : WidgetSnapshot.load(), isPreview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockinEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.load()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        var dates: Set<Date> = [now, midnight]
        (snapshot.friendsLocked ?? []).map(\.until).filter { $0 > now && $0 <= midnight }.forEach { dates.insert($0) }
        let entries = dates.sorted().map { LockinEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(min(midnight, now.addingTimeInterval(30 * 60)))))
    }
}

extension WidgetSnapshot {
    static var socialPreview: WidgetSnapshot {
        var snapshot = WidgetSnapshot.preview
        let now = Date()
        snapshot.friendsLocked = [
            .init(id: UUID(), name: "Sara", until: now.addingTimeInterval(23 * 60)),
            .init(id: UUID(), name: "Daniel", until: now.addingTimeInterval(48 * 60)),
            .init(id: UUID(), name: "Maya", until: now.addingTimeInterval(24 * 3600), since: now.addingTimeInterval(-70 * 60), isOpen: true),
        ]
        snapshot.goals = [.init(id: UUID(), title: "Exam day", symbol: "graduationcap.fill", targetDate: now.addingTimeInterval(23 * 86_400), createdAt: now.addingTimeInterval(-30 * 86_400))]
        snapshot.plannedItems = [
            .init(id: UUID(), title: "Essay due", symbol: "flag.fill", date: now.addingTimeInterval(2 * 86_400)),
            .init(id: UUID(), title: "Maths quiz", symbol: "graduationcap.fill", date: now.addingTimeInterval(5 * 86_400)),
        ]
        return snapshot
    }
}

// MARK: - Friends locked in

struct LockinFriendsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockinFriendsWidget", provider: SocialProvider()) { entry in
            FriendsWidgetView(entry: entry)
        }
        .configurationDisplayName("Friends locked in")
        .description("See who's locked in right now.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct WidgetAvatar: View {
    let name: String
    let id: UUID
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let url = AppGroup.avatarURL(for: id), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(Brand.orange.opacity(0.18))
                    .overlay(
                        Text(String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(Brand.orange)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct FriendsWidgetView: View {
    let entry: LockinEntry
    @Environment(\.widgetFamily) private var family

    private var friends: [WidgetSnapshot.FriendInfo] {
        (entry.snapshot.friendsLocked ?? []).filter { $0.until > entry.date }
    }

    var body: some View {
        Group {
            if family == .systemMedium || family == .systemLarge { medium } else { small }
        }
        .widgetBackground()
    }

    private func time(_ friend: WidgetSnapshot.FriendInfo) -> some View {
        Group {
            if friend.isOpen, let since = friend.since {
                Text(since, style: .timer)
            } else {
                Text(friend.until, style: .timer)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }

    private var header: some View {
        Label("Locked in", systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.orange)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text("Nobody right now")
                .font(.subheadline.weight(.semibold))
            Text("Be the first to lock in.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var small: some View {
        Group {
            if friends.isEmpty {
                empty
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    Spacer(minLength: 0)
                    HStack(spacing: -10) {
                        ForEach(friends.prefix(3)) { friend in
                            WidgetAvatar(name: friend.name, id: friend.id, size: 34)
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        }
                    }
                    Text(friends.count == 1 ? friends[0].name : "\(friends.count) friends")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        time(friends[0])
                        Text(friends[0].isOpen ? "so far" : "left")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private var medium: some View {
        Group {
            if friends.isEmpty {
                empty
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    ForEach(friends.prefix(family == .systemLarge ? 7 : 3)) { friend in
                        HStack(spacing: 10) {
                            WidgetAvatar(name: friend.name, id: friend.id, size: 30)
                            Text(friend.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            HStack(spacing: 4) {
                                time(friend)
                                Text(friend.isOpen ? "so far" : "left")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Goal countdown

struct LockinGoalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockinGoalWidget", provider: SocialProvider()) { entry in
            GoalWidgetView(entry: entry)
        }
        .configurationDisplayName("Goal countdown")
        .description("Days until your goal, and what's coming up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

struct GoalWidgetView: View {
    let entry: LockinEntry
    @Environment(\.widgetFamily) private var family

    private var goal: WidgetSnapshot.GoalInfo? {
        (entry.snapshot.goals ?? []).filter { $0.daysLeft(from: entry.date) >= 0 }.min { $0.targetDate < $1.targetDate }
    }

    private var upcoming: [WidgetSnapshot.PlannedInfo] {
        (entry.snapshot.plannedItems ?? []).filter { $0.date >= Calendar.current.startOfDay(for: entry.date) }
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium, .systemLarge: medium
        default: small
        }
    }

    private func gradient() -> some View {
        LinearGradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.25), Color(red: 0.95, green: 0.30, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private func background() -> some View {
        if #available(iOS 17.0, *) {
            Color.clear.containerBackground(for: .widget) { gradient() }
        } else {
            gradient()
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "flag.checkered").font(.title3).foregroundStyle(Brand.orange)
            Spacer(minLength: 0)
            Text("No goal yet").font(.subheadline.weight(.semibold))
            Text("Set one in Lockin.").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground()
    }

    private var small: some View {
        Group {
            if let goal {
                let days = goal.daysLeft(from: entry.date)
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: goal.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.22), in: Circle())
                    Spacer(minLength: 0)
                    Text("\(days)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text(days == 0 ? "today" : (days == 1 ? "day to go" : "days to go"))
                        .font(.caption.weight(.semibold))
                    Text(goal.title)
                        .font(.caption)
                        .opacity(0.9)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(background())
            } else {
                emptyView
            }
        }
    }

    private var medium: some View {
        Group {
            if let goal {
                let days = goal.daysLeft(from: entry.date)
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: goal.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.22), in: Circle())
                        Spacer(minLength: 0)
                        Text("\(days)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                        Text(days == 1 ? "day to go" : "days to go").font(.caption.weight(.semibold))
                        Text(goal.title).font(.caption).opacity(0.9).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming up").font(.caption.weight(.semibold)).opacity(0.85)
                        if upcoming.isEmpty {
                            Text("Nothing else planned").font(.caption).opacity(0.85)
                        }
                        ForEach(upcoming.prefix(family == .systemLarge ? 4 : 3)) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.symbol).font(.caption2)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                                    Text(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                        .font(.caption2)
                                        .opacity(0.85)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .foregroundStyle(.white)
                .background(background())
            } else {
                emptyView
            }
        }
    }

    private var circular: some View {
        Group {
            if let goal {
                VStack(spacing: 0) {
                    Image(systemName: goal.symbol).font(.system(size: 11))
                    Text("\(goal.daysLeft(from: entry.date))").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("days").font(.system(size: 9))
                }
            } else {
                Image(systemName: "flag.checkered")
            }
        }
        .widgetAccentable()
        .accessoryBackground()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let goal {
                Text(goal.title).font(.headline).lineLimit(1).widgetAccentable()
                Text("\(goal.daysLeft(from: entry.date)) days to go").font(.caption)
                if let next = upcoming.first { Text("Next: \(next.title)").font(.caption).lineLimit(1) }
            } else {
                Text("No goal set").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessoryBackground()
    }
}
