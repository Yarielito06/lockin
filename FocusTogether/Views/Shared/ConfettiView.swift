import SwiftUI

/// A one-shot confetti burst drawn with Canvas. Positions are computed from elapsed time,
/// so there is no per-frame state to update.
struct ConfettiView: View {
    var particleCount = 140
    var lifetime: TimeInterval = 6

    @State private var particles: [ConfettiParticle] = []
    @State private var startDate = Date()
    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(paused: isFinished)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                for particle in particles {
                    let position = particle.position(at: elapsed, in: size)
                    guard position.y < size.height + 40 else { continue }

                    var ctx = context
                    ctx.translateBy(x: position.x, y: position.y)
                    ctx.rotate(by: .degrees(particle.rotation + particle.spin * elapsed))
                    // Squash horizontally over time so pieces look like they flip in 3D.
                    ctx.scaleBy(x: cos(elapsed * particle.flutter), y: 1)
                    let rect = CGRect(
                        x: -particle.size.width / 2, y: -particle.size.height / 2,
                        width: particle.size.width, height: particle.size.height
                    )
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(particle.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            particles = (0..<particleCount).map { _ in ConfettiParticle.random() }
            startDate = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { isFinished = true }
        }
    }
}

private struct ConfettiParticle {
    let angle: Double          // launch direction, radians (0 = right, -π/2 = up)
    let speed: Double          // points per second
    let terminalVelocity: Double
    let drag: Double
    let rotation: Double
    let spin: Double           // degrees per second
    let flutter: Double        // radians per second
    let size: CGSize
    let color: Color

    private static let palette: [Color] = [.pink, .orange, .yellow, .green, .mint, .blue, .purple]

    static func random() -> ConfettiParticle {
        ConfettiParticle(
            angle: -Double.pi / 2 + .random(in: -1.1...1.1),
            speed: .random(in: 450...1100),
            terminalVelocity: .random(in: 90...170),
            drag: .random(in: 1.4...2.2),
            rotation: .random(in: 0...360),
            spin: .random(in: -360...360),
            flutter: .random(in: 4...10),
            size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
            color: palette.randomElement() ?? .pink
        )
    }

    /// Launched from just above the bottom centre, slowed by drag towards a gentle fall
    /// (closed-form solution of dv/dt = -k(v - v_terminal)).
    func position(at t: TimeInterval, in size: CGSize) -> CGPoint {
        let decay = (1 - exp(-drag * t)) / drag
        let vx = cos(angle) * speed
        let vy = sin(angle) * speed
        let x = size.width / 2 + vx * decay + sin(t * flutter / 2) * 8
        let y = size.height * 0.85 + (vy - terminalVelocity) * decay + terminalVelocity * t
        return CGPoint(x: x, y: y)
    }
}
