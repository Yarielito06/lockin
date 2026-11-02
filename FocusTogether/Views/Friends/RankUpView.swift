import SwiftUI

/// Full-screen "you ranked up" moment: the new badge, your hours, and a card to share.
struct RankUpView: View {
    let rank: FocusRank

    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var social: SocialStore
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var shareItems: [Any] = []
    @State private var isSharing = false

    private var hours: Int { history.totalMinutes / 60 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.04, blue: 0.06), Color(red: 0.12, green: 0.08, blue: 0.07)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [rank.colors[0].opacity(0.5), .clear], center: .center, startRadius: 10, endRadius: 320)
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)
                .offset(y: -60)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Text("RANK UP")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(rank.colors[0])
                    .opacity(appeared ? 1 : 0)

                RankBadge(rank: rank, size: 150)
                    .scaleEffect(appeared ? 1 : 0.2)
                    .rotationEffect(.degrees(appeared ? 0 : -25))

                VStack(spacing: 8) {
                    Text(rank.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(hours) hours locked in. That's real work.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                if let next = rank.next {
                    VStack(spacing: 6) {
                        ProgressBar(progress: min(1, Double(history.totalMinutes - rank.minutes) / Double(max(1, next.minutes - rank.minutes))), tint: rank.colors[0])
                            .frame(height: 6)
                        Text("Next: \(next.title) at \(next.minutes / 60) hours")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 50)
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)
                } else {
                    Text("You reached the top.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                VStack(spacing: 10) {
                    Button(action: share) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(.black)
                            .background(.white, in: Capsule())
                    }
                    Button("Keep going") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(height: 40)
                }
            }
            .padding(Theme.gutter)

            ConfettiView()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) { appeared = true }
        }
        .sheet(isPresented: $isSharing) { ShareSheet(items: shareItems).presentationDetents([.medium, .large]) }
    }

    private func share() {
        let poster = RankPoster(rank: rank, name: social.me?.displayName ?? "I", hours: hours).padding(20)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lockin-rank.png")
        try? data.write(to: url, options: .atomic)
        shareItems = [url]
        isSharing = true
    }
}

/// The picture that gets shared.
private struct RankPoster: View {
    let rank: FocusRank
    let name: String
    let hours: Int

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color(red: 0.13, green: 0.08, blue: 0.06)], startPoint: .top, endPoint: .bottom)
            Circle().fill(rank.colors[0].opacity(0.35)).frame(width: 300, height: 300).blur(radius: 70).offset(y: -40)
            VStack(spacing: 18) {
                Image("LogoDark")
                    .resizable().scaledToFit().frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                RankBadge(rank: rank, size: 120)
                Text(rank.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(name) · \(hours) hours locked in")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("Lockin")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(24)
        }
        .frame(width: 340, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
