import SwiftUI

// MARK: Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
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
        Circle()
            .fill(isMe ? Color.primary : color.opacity(0.18))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(isMe ? Theme.background : color)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AvatarStack: View {
    let names: [String]
    var size: CGFloat = 28
    var ringColor: Color = Theme.surface

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(names.prefix(4).enumerated()), id: \.offset) { _, name in
                Avatar(name: name, size: size)
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
