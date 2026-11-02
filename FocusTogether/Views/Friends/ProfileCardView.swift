import SwiftUI

// MARK: - Data

/// What a profile card shows. Built from your own stats or from a friend's synced status.
struct ProfileCardInfo {
    let name: String
    var isLockedIn = false
    var weekMinutes: Int
    var streak: Int
    /// All-time focus minutes (yours only).
    var totalMinutes: Int?
    /// Focus minutes for each day of this week, Monday first (yours only).
    var dayMinutes: [Int]?
    var inviteCode: String?

    /// A fun title that grows with the week's focus.
    var title: String {
        switch weekMinutes {
        case ..<1: "Getting started"
        case ..<180: "Warming up"
        case ..<420: "In the zone"
        case ..<720: "Deep worker"
        default: "Locked-in legend"
        }
    }

    var stats: [(value: String, label: String)] {
        var items: [(String, String)] = [(weekMinutes.minutesLabel, "this week"), ("\(streak)", "day streak")]
        if let totalMinutes { items.append((totalMinutes.minutesLabel, "all time")) }
        return items
    }
}

enum CardStyle: String, CaseIterable, Identifiable {
    case midnight = "Midnight"
    case ember = "Ember"
    case paper = "Paper"

    var id: String { rawValue }

    var background: [Color] {
        switch self {
        case .midnight: [Color(red: 0.05, green: 0.05, blue: 0.06), Color(red: 0.13, green: 0.08, blue: 0.06)]
        case .ember: [Color(red: 1.0, green: 0.60, blue: 0.25), Color(red: 1.0, green: 0.31, blue: 0.14)]
        case .paper: [Color(red: 1.0, green: 0.985, blue: 0.96), Color(red: 1.0, green: 0.91, blue: 0.84)]
        }
    }

    var glow: Color {
        switch self {
        case .midnight: Color(red: 1.0, green: 0.42, blue: 0.18)
        case .ember: Color(red: 1.0, green: 0.85, blue: 0.45)
        case .paper: Color(red: 1.0, green: 0.62, blue: 0.30)
        }
    }

    var ink: Color { self == .paper ? Color(red: 0.1, green: 0.08, blue: 0.07) : .white }
    var softInk: Color { ink.opacity(0.62) }
    var chip: Color { self == .paper ? Color.black.opacity(0.06) : Color.white.opacity(self == .ember ? 0.22 : 0.10) }
    var accent: Color { self == .ember ? .white : Color(red: 1.0, green: 0.42, blue: 0.18) }
}

// MARK: - Card

/// A poster-style profile card made to be screenshotted or shared.
struct ProfileCard: View {
    let info: ProfileCardInfo
    var style: CardStyle = .midnight

    private var initials: String {
        String(info.name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: style.background, startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(style.glow.opacity(style == .paper ? 0.35 : 0.30))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 80, y: -120)
            Circle()
                .fill(style.glow.opacity(style == .paper ? 0.22 : 0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: -110, y: 170)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(style.accent)
                        Text("Lockin")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    if info.isLockedIn {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("Locked in")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(style.chip, in: Capsule())
                    }
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(style.glow.opacity(0.5))
                        .frame(width: 110, height: 110)
                        .blur(radius: 24)
                    Circle()
                        .fill(LinearGradient(colors: [style.glow, style.accent.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 104, height: 104)
                    Circle()
                        .fill(style == .paper ? Color.white : Color.black.opacity(style == .ember ? 0.25 : 0.88))
                        .frame(width: 96, height: 96)
                    Text(initials)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(style == .paper ? Color(red: 1.0, green: 0.42, blue: 0.18) : .white)
                }

                Text(info.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 16)

                Text(info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(style.chip, in: Capsule())
                    .padding(.top, 8)

                Spacer(minLength: 16)

                HStack(spacing: 0) {
                    ForEach(Array(info.stats.enumerated()), id: \.offset) { index, stat in
                        if index > 0 {
                            Rectangle().fill(style.ink.opacity(0.14)).frame(width: 1, height: 30)
                        }
                        VStack(spacing: 3) {
                            HStack(spacing: 4) {
                                if stat.label == "day streak" {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(info.streak > 0 ? style.accent : style.softInk)
                                }
                                Text(stat.value)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Text(stat.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(style.softInk)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if let days = info.dayMinutes {
                    weekBars(days)
                        .padding(.top, 18)
                }

                if let code = info.inviteCode {
                    HStack(spacing: 6) {
                        Text("Add me")
                            .foregroundStyle(style.softInk)
                        Text(code)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.top, 18)
                }
            }
            .foregroundStyle(style.ink)
            .padding(24)
        }
        .frame(width: 340, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(style.ink.opacity(style == .paper ? 0.08 : 0.12), lineWidth: 1)
        )
    }

    private func weekBars(_ days: [Int]) -> some View {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let best = max(1, days.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<min(7, days.count), id: \.self) { index in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(days[index] > 0 ? style.accent : style.ink.opacity(0.14))
                        .frame(height: max(6, 34 * CGFloat(days[index]) / CGFloat(best)))
                    Text(letters[index])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(style.softInk)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 52, alignment: .bottom)
    }
}

// MARK: - Your profile

/// Your own card: swipe between looks, then share it as an image.
struct MyProfileView: View {
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var style: CardStyle = .midnight
    @State private var rendered: UIImage?
    @State private var didCopy = false

    private var info: ProfileCardInfo {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        // Monday-first, whatever the locale's first weekday is.
        let days = (0..<7).map { offset -> Int in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return 0 }
            return history.sessions(on: day).reduce(0) { $0 + $1.minutes }
        }
        let weekdayOrder = (0..<7).map { (calendar.component(.weekday, from: calendar.date(byAdding: .day, value: $0, to: start) ?? start) + 5) % 7 }
        var monday = [Int](repeating: 0, count: 7)
        for (offset, slot) in weekdayOrder.enumerated() { monday[slot] = days[offset] }
        return ProfileCardInfo(
            name: social.me?.displayName ?? "You",
            isLockedIn: false,
            weekMinutes: history.weekMinutes,
            streak: history.streakDays,
            totalMinutes: history.records.reduce(0) { $0 + $1.minutes },
            dayMinutes: monday,
            inviteCode: social.me?.inviteCode
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                TabView(selection: $style) {
                    ForEach(CardStyle.allCases) { option in
                        ProfileCard(info: info, style: option)
                            .shadow(color: option.glow.opacity(0.35), radius: 24, y: 10)
                            .tag(option)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 500)

                HStack(spacing: 8) {
                    ForEach(CardStyle.allCases) { option in
                        ChipButton(title: option.rawValue, isSelected: option == style) {
                            Haptics.select()
                            withAnimation(Theme.spring) { style = option }
                        }
                    }
                }

                VStack(spacing: 10) {
                    if let rendered {
                        ShareLink(
                            item: Image(uiImage: rendered),
                            preview: SharePreview("My Lockin card", image: Image(uiImage: rendered))
                        ) {
                            Label("Share my card", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(Theme.background)
                                .background(Color.primary, in: Capsule())
                        }
                    }
                    if let code = social.me?.inviteCode {
                        Button {
                            UIPasteboard.general.string = code
                            Haptics.success()
                            didCopy = true
                        } label: {
                            Text(didCopy ? "Copied \(code)" : "Copy invite code · \(code)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle("My card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task(id: style) { render() }
        }
    }

    private func render() {
        let renderer = ImageRenderer(content: ProfileCard(info: info, style: style).padding(20).background(Color.clear))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
