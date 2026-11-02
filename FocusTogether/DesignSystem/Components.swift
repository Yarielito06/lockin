import SwiftUI

// MARK: Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        let padded = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        if BlockingManager.isOnMac {
            // Liquid glass on the Mac, over the colour drifting behind it.
            if #available(iOS 26.0, *) {
                padded.glassEffect(.regular, in: shape)
            } else {
                padded.background { shape.fill(.thinMaterial).overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 1)) }
            }
        } else {
            padded.background(Theme.surface, in: shape)
        }
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: Buttons

/// Full-width ink capsule used for the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Theme.background : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isEnabled ? Color.primary : Theme.surface, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// Small round icon button, e.g. the "+" in a screen header.
struct CircleIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Theme.background : .primary)
                .background(isSelected ? Color.primary : Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A segmented control drawn as a capsule with a sliding thumb.
struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    Haptics.select()
                    withAnimation(Theme.spring) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.background)
                                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "thumb", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
    }
}

// MARK: Text

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.largeTitle.bold())
            }
            Spacer()
            trailing
        }
        .padding(.top, 12)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Avatars

struct Avatar: View {
    let name: String
    var size: CGFloat = 40
    var isMe = false
    /// Pass a person's id to show their profile photo when they have one.
    var userID: UUID?

    @EnvironmentObject private var avatars: AvatarStore

    private static let palette: [Color] = [.orange, .blue, .green, .pink, .purple, .teal, .indigo, .mint]

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    /// Stable per name (String.hashValue changes between launches).
    private var color: Color {
        let seed = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.palette[seed % Self.palette.count]
    }

    var body: some View {
        Group {
            if let image = avatars.image(for: userID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(isMe ? Color.primary : color.opacity(0.18))
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                            .foregroundStyle(isMe ? Theme.background : color)
                    )
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

struct AvatarStack: View {
    let names: [String]
    /// Same order as `names`; lets people with a profile photo show it.
    var ids: [UUID] = []
    var size: CGFloat = 28
    var ringColor: Color = Theme.surface

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(names.prefix(4).enumerated()), id: \.offset) { index, name in
                Avatar(name: name, size: size, userID: ids.indices.contains(index) ? ids[index] : nil)
                    .background(Circle().fill(Theme.background))
                    .overlay(Circle().stroke(ringColor, lineWidth: 2))
            }
            if names.count > 4 {
                Text("+\(names.count - 4)")
                    .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                    .frame(width: size, height: size)
                    .background(Circle().fill(Theme.background))
                    .overlay(Circle().stroke(ringColor, lineWidth: 2))
            }
        }
    }
}

// MARK: Progress

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(Theme.spring, value: progress)
    }
}

struct ProgressBar: View {
    let progress: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Theme.track)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.height, geo.size.width * min(1, max(0, progress))))
                }
        }
        .frame(height: 6)
        .animation(Theme.spring, value: progress)
    }
}


// MARK: Swipe to delete

private struct SwipeToDelete: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat
    /// Ask before deleting (the card springs back first) instead of flying away.
    let confirmFirst: Bool
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0     // negative while swiping left
    @State private var isOpen = false
    @State private var isPastThreshold = false
    @State private var isGone = false

    private let revealWidth: CGFloat = 96
    private let threshold: CGFloat = 150

    private var pull: CGFloat { max(0, -offset) }

    func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else {
            content
                .offset(x: offset)
                .opacity(isGone ? 0 : 1)
                .background(alignment: .trailing) { deleteLayer }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged(changed)
                        .onEnded(ended)
                )
        }
    }

    /// Red slab that fills in behind the card, with a trash can that pops when you've pulled far enough.
    private var deleteLayer: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.red.opacity(0.55 + 0.45 * min(1, pull / threshold)))
            Button {
                fire()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isPastThreshold ? "trash.fill" : "trash")
                        .font(.system(size: 20, weight: .semibold))
                        .scaleEffect(isPastThreshold ? 1.3 : 1)
                        .rotationEffect(.degrees(isPastThreshold ? -12 : 0))
                    Text(isPastThreshold ? "Release" : "Delete")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: revealWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .opacity(pull > 24 ? 1 : 0)
        }
        .opacity(pull > 1 ? 1 : 0)
    }

    private func changed(_ drag: DragGesture.Value) {
        // Only a mostly sideways drag counts, so scrolling still works.
        guard abs(drag.translation.width) > abs(drag.translation.height) * 1.4 else { return }
        let start: CGFloat = isOpen ? -revealWidth : 0
        let raw = start + drag.translation.width
        // Left pulls the card; right just stretches a little.
        offset = raw > 0 ? raw / 8 : max(raw, -(threshold + 90))
        let past = pull > threshold
        if past != isPastThreshold {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { isPastThreshold = past }
            if past { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() } else { Haptics.select() }
        }
    }

    private func ended(_ drag: DragGesture.Value) {
        if pull > threshold {
            fire()
        } else if pull > revealWidth * 0.5 {
            withAnimation(Theme.spring) { offset = -revealWidth }
            isOpen = true
            isPastThreshold = false
        } else {
            close()
        }
    }

    private func fire() {
        if confirmFirst {
            close()
            onDelete()
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeIn(duration: 0.22)) {
            offset = -600
            isGone = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            onDelete()
            // In case the card sticks around (e.g. the delete was cancelled), bring it back.
            offset = 0
            isGone = false
            isOpen = false
            isPastThreshold = false
        }
    }

    private func close() {
        withAnimation(Theme.spring) {
            offset = 0
            isPastThreshold = false
        }
        isOpen = false
    }
}

extension View {
    /// Swipe left to reveal Delete; pull past the mark and let go to delete.
    func swipeToDelete(enabled: Bool = true, cornerRadius: CGFloat = Theme.cornerRadius, confirmFirst: Bool = false, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(isEnabled: enabled, cornerRadius: cornerRadius, confirmFirst: confirmFirst, onDelete: onDelete))
    }
}
