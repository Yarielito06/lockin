import SwiftUI

/// Send a friend who's locked in a quick cheer. Tap, pick an emoji, they get a push and see it on their lock screen.
struct CheerMenu: View {
    static let emojis = ["🔥", "💪", "👏", "🙏", "❤️"]

    let friend: Friend
    var style: Style = .capsule

    enum Style { case capsule, large }

    @EnvironmentObject private var social: SocialStore
    @State private var sentEmoji: String?
    @State private var error: String?

    var body: some View {
        Group {
            switch style {
            case .capsule:
                Menu { items } label: {
                    Text(sentEmoji.map { "Sent \($0)" } ?? "Cheer")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }
            case .large:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(Self.emojis, id: \.self) { emoji in
                            Button { send(emoji) } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 52, height: 52)
                                    .background(sentEmoji == emoji ? Theme.accent.opacity(0.2) : Theme.surface, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(error ?? (sentEmoji != nil ? "Sent — they'll see it" : "Cheer \(friend.name) on"))
                        .font(.footnote)
                        .foregroundStyle(error == nil ? Color.secondary : Color.red)
                }
            }
        }
        .animation(Theme.spring, value: sentEmoji)
    }

    @ViewBuilder
    private var items: some View {
        ForEach(Self.emojis, id: \.self) { emoji in
            Button(emoji) { send(emoji) }
        }
    }

    private func send(_ emoji: String) {
        Haptics.success()
        error = nil
        Task {
            if let message = await social.cheer(friend, emoji: emoji) {
                error = message
            } else {
                sentEmoji = emoji
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if sentEmoji == emoji { sentEmoji = nil }
            }
        }
    }
}

/// Cheers from friends during your session, shown under the countdown.
struct CheersStrip: View {
    let since: Date

    @EnvironmentObject private var social: SocialStore

    var body: some View {
        Group {
            if !social.cheers.isEmpty {
                VStack(spacing: 8) {
                    Text("Your friends are cheering")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(social.cheers.prefix(12)) { cheer in
                                Text("\(cheer.emoji) \(cheer.name)")
                                    .font(.footnote.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Theme.surface, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(Theme.spring, value: social.cheers)
        .task(id: since) {
            while !Task.isCancelled {
                if await social.refreshCheers(since: since) { Haptics.success() }
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}
