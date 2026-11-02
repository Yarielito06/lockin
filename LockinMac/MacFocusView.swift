import SwiftUI

/// The big timer: pick free time or a length, start, and watch the ring.
struct MacFocusView: View {
    @EnvironmentObject private var focus: MacFocus
    @EnvironmentObject private var history: HistoryStore
    @State private var choice: Int? = nil   // nil = free time

    private let options: [(label: String, minutes: Int?)] = [("Free", nil), ("25", 25), ("50", 50), ("90", 90)]

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Focus").font(.system(size: 40, weight: .bold, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 26) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        ring(now: context.date)
                    }
                    if focus.isActive {
                        Button { focus.stop() } label: {
                            Label(focus.isFree ? "Stop and save" : "End session", systemImage: "stop.fill")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 260, height: 54)
                                .background(.white, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 10) {
                            ForEach(options, id: \.label) { option in
                                Button { withAnimation(Theme.spring) { choice = option.minutes } } label: {
                                    Text(option.minutes == nil ? "Free" : "\(option.label) min")
                                        .font(.system(size: 16, weight: .semibold))
                                        .padding(.horizontal, 20).padding(.vertical, 11)
                                        .foregroundStyle(choice == option.minutes ? Color.white : Color.primary)
                                        .background(choice == option.minutes ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.1)), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button { focus.start(minutes: choice) } label: {
                            Label("Lock in", systemImage: "lock.fill")
                                .font(.system(size: 19, weight: .bold))
                                .frame(width: 300, height: 58)
                                .background(LinearGradient(colors: [Color(red: 1.0, green: 0.60, blue: 0.30), Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                                .foregroundStyle(.white)
                                .shadow(color: Theme.accent.opacity(0.5), radius: 16, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                    if let saved = focus.lastRecorded, !focus.isActive {
                        Label("Saved \(saved.minutesLabel) to your streak", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accent)
                    }
                    Text("The Mac can't block apps. This timer counts toward your streak and rank, and it's on your iPhone too.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.vertical, 34)
                .frame(maxWidth: .infinity)
                .glassCard(padding: 20, radius: 36)

                recent
            }
            .padding(.horizontal, 40)
            .padding(.top, 54)
            .padding(.bottom, 40)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
    }

    private func ring(now: Date) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 12)
            Circle()
                .trim(from: 0, to: focus.isActive ? max(0.005, focus.progress(at: now)) : 0)
                .stroke(AngularGradient(colors: [Theme.accent.opacity(0.6), Theme.accent], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent.opacity(0.5), radius: 10)
            VStack(spacing: 4) {
                if focus.isActive {
                    Text(focus.isFree ? formatClock(focus.elapsed(at: now)) : formatClock(focus.remaining(at: now)))
                        .font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(focus.isFree ? "free time" : "left").font(.system(size: 16)).foregroundStyle(.secondary)
                } else {
                    Text(choice.map { "\($0)" } ?? "∞").font(.system(size: 76, weight: .bold, design: .rounded))
                    Text(choice == nil ? "until you stop" : "minutes").font(.system(size: 16)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 300, height: 300)
    }

    private var recent: some View {
        let records = Array(history.records.sorted { $0.endDate > $1.endDate }.prefix(6))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent").font(.system(size: 20, weight: .bold, design: .rounded))
            if records.isEmpty {
                Text("Your finished sessions show here, from this Mac and your iPhone.").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            ForEach(records) { record in
                HStack {
                    Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32).background(Theme.accent.opacity(0.16), in: Circle())
                    Text(record.minutes.minutesLabel).font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(record.endDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
        }
        .glassCard(padding: 22, radius: 28)
    }
}
