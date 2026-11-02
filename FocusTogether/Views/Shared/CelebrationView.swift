import SwiftUI

/// Shown once a session finishes: confetti, the minutes focused and the current streak.
struct CelebrationView: View {
    let session: FocusSession

    @EnvironmentObject private var blocking: BlockingManager
    @EnvironmentObject private var history: HistoryStore
    @State private var appeared = false

    var body: some View {
        ZStack {
            VStack(spacing: 28) {
                Spacer()

                Text("Well done!")
                    .font(.largeTitle.bold())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                VStack(spacing: 0) {
                    Text("\(session.durationMinutes)")
                        .font(.system(size: 120, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .scaleEffect(appeared ? 1 : 0.6)
                    Text("minutes locked in")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if let groupName = session.groupName {
                        Text("with \(groupName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

                if history.streakDays > 0 {
                    Label("\(history.streakDays)-day streak", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                        .opacity(appeared ? 1 : 0)
                }

                Spacer()

                Button("Done") { blocking.dismissCelebration() }
                    .buttonStyle(.primary)
            }
            .padding(Theme.gutter)

            ConfettiView()
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
