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

// MARK: - Notch island

/// Where the camera notch is, and how big the island should be around it.
struct NotchMetrics {
    /// Height of the notch, or of a menu bar on Macs without one.
    var height: CGFloat
    /// Width of the notch itself (0 when there isn't one).
    var notchWidth: CGFloat
    var hasNotch: Bool { notchWidth > 0 }

    static func current(for screen: NSScreen) -> NotchMetrics {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchMetrics(height: top, notchWidth: max(0, screen.frame.width - left.width - right.width))
        }
        return NotchMetrics(height: 32, notchWidth: 0)
    }
}

/// A black shape with a flat top (it hangs from the screen edge) and rounded bottom corners.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The Dynamic Island for the Mac: while you're locked in, the notch grows sideways to show the lock and the
/// time, and drops down with a Stop button when you hover or click it.
@MainActor
final class IslandController {
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?
    private let focus: MacFocus
    private let model = IslandModel()
    private var collapseWork: DispatchWorkItem?

    static let sideExtra: CGFloat = 96
    static let dropDown: CGFloat = 86

    init(focus: MacFocus) {
        self.focus = focus
        model.onExpandedChange = { [weak self] expanded in self?.setExpanded(expanded) }
        cancellable = focus.$startDate.receive(on: DispatchQueue.main).sink { [weak self] start in
            if start == nil { self?.hide() } else { self?.show() }
        }
    }

    private var screen: NSScreen? { NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main }

    private func frame(expanded: Bool) -> NSRect {
        guard let screen else { return .zero }
        let metrics = NotchMetrics.current(for: screen)
        model.metrics = metrics
        let width = (metrics.hasNotch ? metrics.notchWidth : 120) + Self.sideExtra * 2 + (expanded ? 60 : 0)
        let height = metrics.height + (expanded ? Self.dropDown : 0)
        return NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
    }

    private func show() {
        guard panel == nil, screen != nil else { return }
        let panel = NSPanel(contentRect: frame(expanded: false), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: IslandView(model: model).environmentObject(focus))
        panel.orderFrontRegardless()
        self.panel = panel
        model.expanded = false
    }

    private func hide() {
        collapseWork?.cancel()
        panel?.orderOut(nil)
        panel = nil
        model.expanded = false
    }

    private func setExpanded(_ expanded: Bool) {
        collapseWork?.cancel()
        guard let panel else { return }
        if expanded {
            // Grow the window first, then let the island animate inside it.
            panel.setFrame(frame(expanded: true), display: true)
        } else {
            let work = DispatchWorkItem { [weak self, weak panel] in
                guard let self, let panel else { return }
                panel.setFrame(self.frame(expanded: false), display: true)
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }
    }
}

@MainActor
final class IslandModel: ObservableObject {
    @Published var expanded = false { didSet { if expanded != oldValue { onExpandedChange?(expanded) } } }
    @Published var metrics = NotchMetrics(height: 32, notchWidth: 0)
    var onExpandedChange: ((Bool) -> Void)?
}

struct IslandView: View {
    @ObservedObject var model: IslandModel
    @EnvironmentObject private var focus: MacFocus
    @State private var pulse = false
    @State private var hoverWork: DispatchWorkItem?

    var body: some View {
        let metrics = model.metrics
        let side = IslandController.sideExtra
        let width = (metrics.hasNotch ? metrics.notchWidth : 120) + side * 2 + (model.expanded ? 60 : 0)
        let height = metrics.height + (model.expanded ? IslandController.dropDown : 0)

        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                // Row beside the notch: the lock on the left, the time on the right.
                HStack(spacing: 0) {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                            .shadow(color: Theme.accent.opacity(0.9), radius: pulse ? 6 : 1)
                    }
                    .frame(width: side + (model.expanded ? 30 : 0), alignment: .center)

                    Spacer(minLength: metrics.hasNotch ? metrics.notchWidth : 0)

                    Text(focus.isFree ? formatClock(focus.elapsed(at: context.date)) : formatClock(focus.remaining(at: context.date)))
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: side + (model.expanded ? 30 : 0), alignment: .center)
                }
                .frame(height: metrics.height)

                if model.expanded {
                    VStack(spacing: 10) {
                        if !focus.isFree {
                            ProgressView(value: focus.progress(at: context.date)).tint(Theme.accent).padding(.horizontal, 24)
                        }
                        HStack {
                            Text(focus.isFree ? "Free time" : "Locked in").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Button { focus.stop() } label: {
                                Text(focus.isFree ? "Stop" : "End").font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 18).padding(.vertical, 6)
                                    .background(.white, in: Capsule()).foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(height: IslandController.dropDown - 10, alignment: .top)
                    .transition(.opacity)
                }
            }
            .frame(width: width, height: height, alignment: .top)
            .background(NotchShape(bottomRadius: model.expanded ? 28 : 16).fill(Color.black))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: model.expanded)
        .onHover { inside in
            hoverWork?.cancel()
            let work = DispatchWorkItem { model.expanded = inside }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? 0.12 : 0.35), execute: work)
        }
        .onTapGesture { model.expanded.toggle() }
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true } }
    }
}
