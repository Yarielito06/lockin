import SwiftUI

/// Hold two phones together to become friends. Both people open this screen.
struct AddNearbyView: View {
    @StateObject private var nearby: NearbyManager
    @Environment(\.dismiss) private var dismiss
    @State private var pulse = false

    init(name: String, code: String, onMatch: @escaping (String) async -> String?) {
        _nearby = StateObject(wrappedValue: NearbyManager(name: name, code: code, onMatch: onMatch))
    }

    /// 0 when far (or unknown), 1 when the phones are touching.
    private var closeness: Double {
        guard let distance = nearby.distance else { return 0 }
        return min(1, max(0, Double(1 - (distance - 0.2) / 1.3)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                rings
                    .frame(width: 260, height: 260)
                status
                Spacer()
                footer
            }
            .padding(Theme.gutter)
            .frame(maxWidth: .infinity)
            .navigationTitle("Add nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            nearby.start()
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
        .onDisappear { nearby.stop() }
    }

    // MARK: Pieces

    private var rings: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(ringColor.opacity(0.35 - Double(index) * 0.1), lineWidth: 2)
                    .scaleEffect(pulse ? 1 : 0.4 + Double(index) * 0.15)
                    .opacity(pulse ? 0 : 1)
                    .animation(
                        .easeOut(duration: max(0.5, 1.6 - closeness * 1.1))
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.35),
                        value: pulse
                    )
            }
            .opacity(isFinished ? 0 : 1)

            Circle()
                .fill(isFinished ? Theme.accent : Color.primary)
                .frame(width: 96 + closeness * 40, height: 96 + closeness * 40)
                .animation(Theme.spring, value: closeness)
                .overlay(centerIcon)
        }
        .animation(Theme.spring, value: nearby.phase)
    }

    @ViewBuilder
    private var centerIcon: some View {
        switch nearby.phase {
        case .adding:
            ProgressView().tint(Theme.background).scaleEffect(1.3)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .transition(.scale.combined(with: .opacity))
        case .found(let name):
            Text(initials(name))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.background)
        default:
            Image(systemName: "wave.3.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.background)
        }
    }

    @ViewBuilder
    private var status: some View {
        VStack(spacing: 8) {
            switch nearby.phase {
            case .searching:
                Text("Looking for friends nearby")
                    .font(.title3.bold())
                Text("Ask your friend to open Add nearby too.")
                    .foregroundStyle(.secondary)
            case .found(let name):
                Text("\(name) is nearby")
                    .font(.title3.bold())
                Text(nearby.supportsDistance && nearby.distance != nil
                     ? "Hold your phones together"
                     : "Tap below to add them")
                    .foregroundStyle(.secondary)
                if let distance = nearby.distance {
                    Text(distance < 1 ? "\(Int(distance * 100)) cm" : String(format: "%.1f m", distance))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                }
            case .adding(let name):
                Text("Adding \(name)…")
                    .font(.title3.bold())
            case .done(let message):
                Text(message)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
            case .failed(let message):
                Text(message)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .animation(Theme.spring, value: nearby.phase)
    }

    @ViewBuilder
    private var footer: some View {
        switch nearby.phase {
        case .found(let name):
            Button("Add \(name)") { nearby.addFoundPeer() }
                .buttonStyle(.primary)
        case .done:
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
        default:
            Text("Works when both phones have Lockin open on this screen, with Wi‑Fi and Bluetooth on.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var isFinished: Bool {
        if case .done = nearby.phase { return true }
        return false
    }

    private var ringColor: Color {
        if case .found = nearby.phase { return Theme.accent }
        return Color.primary
    }

    private func initials(_ name: String) -> String {
        String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }
}
