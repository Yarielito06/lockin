import AppKit
import Combine
import SwiftUI

/// The menu-bar timer.
struct MenuBarLabel: View {
    @EnvironmentObject private var focus: MacFocus

    var body: some View {
        if focus.isActive, let start = focus.startDate {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                if let end = focus.endDate { Text(end, style: .timer).monospacedDigit() } else { Text(start, style: .timer).monospacedDigit() }
            }
        } else {
            Image(systemName: "lock.open")
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var focus: MacFocus
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if focus.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(focus.isFree ? formatClock(focus.elapsed(at: context.date)) : formatClock(focus.remaining(at: context.date)))
                        .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                }
                Button(focus.isFree ? "Stop and save" : "End session") { focus.stop() }
            } else {
                Text("Lockin").font(.headline)
                Button("Lock in — free time") { focus.start(minutes: nil) }
                HStack {
                    ForEach([25, 50, 90], id: \.self) { m in Button("\(m) min") { focus.start(minutes: m) } }
                }
            }
            Divider()
            Button("Open Lockin") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(16)
        .frame(width: 240)
    }
}

/// A floating pill at the top of the screen while you're locked in, like an island.
@MainActor
final class IslandController {
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?
    private let focus: MacFocus
    private var expanded = false

    init(focus: MacFocus) {
        self.focus = focus
        cancellable = focus.$startDate.receive(on: DispatchQueue.main).sink { [weak self] start in
            if start == nil { self?.hide() } else { self?.show() }
        }
    }

    private func show() {
        guard panel == nil, let screen = NSScreen.main else { return }
        let size = NSSize(width: 360, height: 60)
        let panel = NSPanel(
            contentRect: NSRect(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 4, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: IslandPill().environmentObject(focus))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct IslandPill: View {
    @EnvironmentObject private var focus: MacFocus
    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 12) {
                Circle().fill(Theme.accent).frame(width: 10, height: 10)
                    .shadow(color: Theme.accent.opacity(0.9), radius: pulse ? 9 : 2)
                Text(focus.isFree ? formatClock(focus.elapsed(at: context.date)) : formatClock(focus.remaining(at: context.date)))
                    .font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                Text(focus.isFree ? "free time" : "locked in").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 4)
                Button { focus.stop() } label: {
                    Text(focus.isFree ? "Stop" : "End").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 6).background(.white, in: Capsule()).foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .frame(width: appeared ? 330 : 140, height: 46)
            .background(Color.black, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.68)) { appeared = true }
        }
    }
}
