import AppKit
import Foundation
import SwiftUI

/// The Mac's focus timer. It can't block apps (Macs have no Screen Time blocking), but it counts toward
/// your streak and ranks, and syncs to your phone through iCloud like everything else.
@MainActor
final class MacFocus: ObservableObject {
    private enum Key {
        static let start = "lockin.mac.start"
        static let minutes = "lockin.mac.minutes"
    }

    @Published private(set) var startDate: Date?
    /// nil for free time.
    @Published private(set) var plannedMinutes: Int?
    @Published private(set) var lastRecorded: Int?

    private let history: HistoryStore
    private var timer: Timer?

    init(history: HistoryStore) {
        self.history = history
        let stored = UserDefaults.standard.double(forKey: Key.start)
        if stored > 0 {
            startDate = Date(timeIntervalSince1970: stored)
            let minutes = UserDefaults.standard.integer(forKey: Key.minutes)
            plannedMinutes = minutes > 0 ? minutes : nil
        }
        schedule()
        finishIfDue()
    }

    var isActive: Bool { startDate != nil }
    var isFree: Bool { plannedMinutes == nil }

    var endDate: Date? {
        guard let startDate, let plannedMinutes else { return nil }
        return startDate.addingTimeInterval(TimeInterval(plannedMinutes * 60))
    }

    func elapsed(at date: Date = .now) -> TimeInterval { startDate.map { max(0, date.timeIntervalSince($0)) } ?? 0 }
    func remaining(at date: Date = .now) -> TimeInterval { endDate.map { max(0, $0.timeIntervalSince(date)) } ?? 0 }

    func progress(at date: Date = .now) -> Double {
        guard let plannedMinutes else { return (elapsed(at: date).truncatingRemainder(dividingBy: 3600)) / 3600 }
        return min(1, elapsed(at: date) / TimeInterval(plannedMinutes * 60))
    }

    func start(minutes: Int?) {
        guard !isActive else { return }
        startDate = .now
        plannedMinutes = minutes
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Key.start)
        UserDefaults.standard.set(minutes ?? 0, forKey: Key.minutes)
        if let minutes {
            let session = FocusSession(startDate: .now, durationMinutes: minutes)
            Task { if await ReminderScheduler.requestPermission() { ReminderScheduler.scheduleSessionEnd(session) } }
        }
        Haptics.success()
        schedule()
    }

    /// Ends the session, counting the time actually spent (a minute or more).
    func stop() {
        guard let startDate else { return }
        ReminderScheduler.cancelSessionEnd()
        let end = Date()
        let session = FocusSession(startDate: startDate, endDate: min(end, endDate ?? end), groupName: nil)
        if session.durationMinutes >= 1 {
            history.record(session)
            lastRecorded = session.durationMinutes
        }
        reset()
        Haptics.success()
    }

    private func reset() {
        startDate = nil
        plannedMinutes = nil
        UserDefaults.standard.removeObject(forKey: Key.start)
        UserDefaults.standard.removeObject(forKey: Key.minutes)
        timer?.invalidate()
        timer = nil
    }

    private func schedule() {
        timer?.invalidate()
        guard isActive else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.finishIfDue() }
        }
    }

    private func finishIfDue() {
        if let endDate, endDate <= .now { stop() }
    }
}

// MARK: - Ranks

enum FocusRank: Int, CaseIterable, Identifiable {
    case newcomer, warmingUp, inTheZone, deepWorker, master, legend

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .newcomer: "Getting started"
        case .warmingUp: "Warming up"
        case .inTheZone: "In the zone"
        case .deepWorker: "Deep worker"
        case .master: "Focus master"
        case .legend: "Locked-in legend"
        }
    }

    var minutes: Int {
        switch self {
        case .newcomer: 0
        case .warmingUp: 600
        case .inTheZone: 3000
        case .deepWorker: 6000
        case .master: 30000
        case .legend: 60000
        }
    }

    var symbol: String {
        switch self {
        case .newcomer: "sparkle"
        case .warmingUp: "flame.fill"
        case .inTheZone: "bolt.fill"
        case .deepWorker: "star.fill"
        case .master: "diamond.fill"
        case .legend: "crown.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .newcomer: [Color(white: 0.74), Color(white: 0.5)]
        case .warmingUp: [Color(red: 0.86, green: 0.55, blue: 0.30), Color(red: 0.62, green: 0.34, blue: 0.16)]
        case .inTheZone: [Color(red: 0.78, green: 0.82, blue: 0.88), Color(red: 0.50, green: 0.56, blue: 0.66)]
        case .deepWorker: [Color(red: 1.0, green: 0.84, blue: 0.35), Color(red: 0.88, green: 0.62, blue: 0.10)]
        case .master: [Color(red: 0.45, green: 0.90, blue: 0.95), Color(red: 0.20, green: 0.55, blue: 0.90)]
        case .legend: [Color(red: 0.80, green: 0.50, blue: 1.0), Color(red: 1.0, green: 0.45, blue: 0.55)]
        }
    }

    static func rank(forMinutes minutes: Int) -> FocusRank {
        allCases.last { minutes >= $0.minutes } ?? .newcomer
    }

    var next: FocusRank? { FocusRank(rawValue: rawValue + 1) }
}

struct RankBadge: View {
    let rank: FocusRank
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: rank.symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: rank.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: size * 0.05))
            .shadow(color: rank.colors[0].opacity(0.5), radius: size * 0.2)
    }
}

func formatClock(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.down)))
    let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
}
