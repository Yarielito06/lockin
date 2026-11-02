import AppKit
import Combine
import SwiftUI

/// The menu-bar item: a lock that shows the live timer while you're locked in, with a quick menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let focus: MacFocus
    private var cancellable: AnyCancellable?
    private var timer: Timer?

    init(focus: MacFocus) {
        self.focus = focus
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        refresh()
        cancellable = focus.$startDate.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: focus.isActive ? "lock.fill" : "lock.open", accessibilityDescription: "Lockin")
        if focus.isActive {
            let seconds = focus.isFree ? focus.elapsed() : focus.remaining()
            button.title = " " + formatClock(seconds)
        } else {
            button.title = ""
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if focus.isActive {
            add(menu, focus.isFree ? "Stop and save" : "End session") { [focus] in focus.stop() }
        } else {
            add(menu, "Lock in — free time") { [focus] in focus.start(minutes: nil) }
            for minutes in [25, 50, 90] { add(menu, "Lock in — \(minutes) minutes") { [focus] in focus.start(minutes: minutes) } }
        }
        menu.addItem(.separator())
        add(menu, "Open Lockin") { MacAppDelegate.ensureWindow() }
        add(menu, "Quit Lockin") { NSApp.terminate(nil) }
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: @escaping () -> Void) {
        let entry = ClosureMenuItem(title: title, action: action)
        menu.addItem(entry)
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
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
