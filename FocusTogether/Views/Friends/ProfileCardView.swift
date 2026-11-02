import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data

/// What a profile card shows. Built from your own stats or from a friend's synced status.
struct ProfileCardInfo {
    let name: String
    var isLockedIn = false
    var weekMinutes: Int
    var streak: Int
    /// All-time focus minutes (yours only).
    var totalMinutes: Int?
    /// Focus minutes for each day of this week, Monday first (yours only).
    var dayMinutes: [Int]?
    var inviteCode: String?
    var avatar: UIImage?

    /// A fun title that grows with the week's focus.
    var title: String {
        switch weekMinutes {
        case ..<1: "Getting started"
        case ..<180: "Warming up"
        case ..<420: "In the zone"
        case ..<720: "Deep worker"
        default: "Locked-in legend"
        }
    }

    var stats: [(value: String, label: String)] {
        var items: [(String, String)] = [(weekMinutes.minutesLabel, "this week"), ("\(streak)", "day streak")]
        if let totalMinutes { items.append((totalMinutes.minutesLabel, "all time")) }
        return items
    }
}

enum CardStyle: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case custom = "Custom"

    var id: String { rawValue }

    var background: [Color] {
        switch self {
        case .dark, .custom: [Color(red: 0.05, green: 0.05, blue: 0.06), Color(red: 0.13, green: 0.08, blue: 0.06)]
        case .light: [Color(red: 1.0, green: 0.985, blue: 0.96), Color(red: 1.0, green: 0.91, blue: 0.84)]
        }
    }

    var glow: Color {
        self == .light ? Color(red: 1.0, green: 0.62, blue: 0.30) : Color(red: 1.0, green: 0.42, blue: 0.18)
    }

    var ink: Color { self == .light ? Color(red: 0.1, green: 0.08, blue: 0.07) : .white }
    var softInk: Color { ink.opacity(0.62) }
    var chip: Color { self == .light ? Color.black.opacity(0.06) : Color.white.opacity(self == .custom ? 0.18 : 0.10) }
    var accent: Color { Color(red: 1.0, green: 0.42, blue: 0.18) }
    var logo: String { self == .light ? "LogoLight" : "LogoDark" }
}

// MARK: - Custom background (a photo or a GIF from your gallery)

/// The frames of a chosen picture; one frame for a photo, several for a GIF.
final class CardBackground {
    let frames: [UIImage]
    let duration: TimeInterval
    var isAnimated: Bool { frames.count > 1 }
    var still: UIImage? { frames.first }

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = min(CGImageSourceGetCount(source), 90)
        guard count > 0 else { return nil }
        var frames: [UIImage] = []
        var total: TimeInterval = 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 900,
        ]
        for index in 0..<count {
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            frames.append(UIImage(cgImage: cg))
            if let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
                total += max(0.04, delay)
            }
        }
        guard !frames.isEmpty else { return nil }
        self.frames = frames
        self.duration = frames.count > 1 ? max(0.4, total) : 0
    }
}

/// Remembers your custom card background between launches.
@MainActor
final class CardBackgroundStore: ObservableObject {
    @Published private(set) var background: CardBackground?

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("card-background.bin")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL) { background = CardBackground(data: data) }
    }

    func set(_ data: Data) {
        guard let new = CardBackground(data: data) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
        background = new
    }

    func clear() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        background = nil
    }
}

/// Plays a GIF's frames.
private struct AnimatedFramesView: UIViewRepresentable {
    let background: CardBackground

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.animationImages = background.frames
        view.animationDuration = background.duration
        view.startAnimating()
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {}
}

// MARK: - Card

/// A poster-style profile card made to be screenshotted or shared.
struct ProfileCard: View {
    let info: ProfileCardInfo
    var style: CardStyle = .dark
    /// For `.custom`: the chosen picture.
    var background: CardBackground?
    /// Draws this single frame instead of playing the animation (used when exporting).
    var stillFrame: UIImage?

    private var initials: String {
        String(info.name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: style.background, startPoint: .top, endPoint: .bottom)
            if style == .custom, background != nil || stillFrame != nil {
                customArt
                LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            }
            Circle()
                .fill(style.glow.opacity(style == .light ? 0.35 : (style == .custom ? 0.10 : 0.30)))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 80, y: -120)
            Circle()
                .fill(style.glow.opacity(style == .light ? 0.22 : (style == .custom ? 0.06 : 0.16)))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: -110, y: 170)

            VStack(spacing: 0) {
                HStack {
                    Image(style.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(style.ink.opacity(0.15), lineWidth: 0.5))
                    Spacer()
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(style.glow.opacity(0.5))
                        .frame(width: 110, height: 110)
                        .blur(radius: 24)
                    Circle()
                        .fill(LinearGradient(colors: [style.glow, style.accent.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 104, height: 104)
                    Circle()
                        .fill(style == .light ? Color.white : Color.black.opacity(0.88))
                        .frame(width: 96, height: 96)
                    if let avatar = info.avatar {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Text(initials)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(style == .light ? style.accent : .white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if info.isLockedIn {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(style == .light ? Color.white : Color.black, lineWidth: 3))
                            .offset(x: -2, y: -2)
                    }
                }

                Text(info.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 16)

                Text(info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(style.chip, in: Capsule())
                    .padding(.top, 8)

                Spacer(minLength: 16)

                HStack(spacing: 0) {
                    ForEach(Array(info.stats.enumerated()), id: \.offset) { index, stat in
                        if index > 0 {
                            Rectangle().fill(style.ink.opacity(0.14)).frame(width: 1, height: 30)
                        }
                        VStack(spacing: 3) {
                            HStack(spacing: 4) {
                                if stat.label == "day streak" {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(info.streak > 0 ? style.accent : style.softInk)
                                }
                                Text(stat.value)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Text(stat.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(style.softInk)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if let days = info.dayMinutes {
                    weekBars(days)
                        .padding(.top, 18)
                }

                if let code = info.inviteCode {
                    HStack(spacing: 6) {
                        Text("Add me")
                            .foregroundStyle(style.softInk)
                        Text(code)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.top, 18)
                }
            }
            .foregroundStyle(style.ink)
            .padding(24)
        }
        .frame(width: 340, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(style.ink.opacity(style == .light ? 0.08 : 0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var customArt: some View {
        if let stillFrame {
            Image(uiImage: stillFrame).resizable().scaledToFill().frame(width: 340, height: 460).clipped()
        } else if let background {
            if background.isAnimated {
                AnimatedFramesView(background: background).frame(width: 340, height: 460)
            } else if let still = background.still {
                Image(uiImage: still).resizable().scaledToFill().frame(width: 340, height: 460).clipped()
            }
        }
    }

    private func weekBars(_ days: [Int]) -> some View {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let best = max(1, days.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<min(7, days.count), id: \.self) { index in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(days[index] > 0 ? style.accent : style.ink.opacity(0.14))
                        .frame(height: max(6, 34 * CGFloat(days[index]) / CGFloat(best)))
                    Text(letters[index])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(style.softInk)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 52, alignment: .bottom)
    }
}

// MARK: - Your profile

/// Your own card: swipe between looks, make it yours, then share it.
struct MyProfileView: View {
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var avatars: AvatarStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var backgrounds = CardBackgroundStore()
    @State private var style: CardStyle = .dark
    @State private var pickerItem: PhotosPickerItem?
    @State private var isEditing = false
    @State private var isPreparing = false
    @State private var shareItems: [Any] = []
    @State private var isSharing = false
    @State private var didCopy = false

    private var info: ProfileCardInfo {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        // Monday-first, whatever the locale's first weekday is.
        var monday = [Int](repeating: 0, count: 7)
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let slot = (calendar.component(.weekday, from: day) + 5) % 7
            monday[slot] = history.sessions(on: day).reduce(0) { $0 + $1.minutes }
        }
        return ProfileCardInfo(
            name: social.me?.displayName ?? "You",
            isLockedIn: false,
            weekMinutes: history.weekMinutes,
            streak: history.streakDays,
            totalMinutes: history.records.reduce(0) { $0 + $1.minutes },
            dayMinutes: monday,
            inviteCode: social.me?.inviteCode,
            avatar: avatars.image(for: social.me?.id)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TabView(selection: $style) {
                        ForEach(CardStyle.allCases) { option in
                            ProfileCard(info: info, style: option, background: backgrounds.background)
                                .shadow(color: option.glow.opacity(0.35), radius: 24, y: 10)
                                .tag(option)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 500)

                    HStack(spacing: 8) {
                        ForEach(CardStyle.allCases) { option in
                            ChipButton(title: option.rawValue, isSelected: option == style) {
                                Haptics.select()
                                withAnimation(Theme.spring) { style = option }
                            }
                        }
                    }

                    if style == .custom { customControls.transition(.opacity) }

                    VStack(spacing: 10) {
                        Button(action: share) {
                            Group {
                                if isPreparing {
                                    ProgressView().tint(Theme.background)
                                } else {
                                    Label("Share my card", systemImage: "square.and.arrow.up")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(Theme.background)
                            .background(Color.primary, in: Capsule())
                        }
                        .disabled(isPreparing)

                        if let code = social.me?.inviteCode {
                            Button {
                                UIPasteboard.general.string = code
                                Haptics.success()
                                didCopy = true
                            } label: {
                                Text(didCopy ? "Copied \(code)" : "Copy invite code · \(code)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: style)
            }
            .navigationTitle("My card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Edit") { isEditing = true } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $isEditing) { EditProfileView() }
            .sheet(isPresented: $isSharing) { ShareSheet(items: shareItems).presentationDetents([.medium, .large]) }
            .onChange(of: pickerItem) { item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) { backgrounds.set(data) }
                    pickerItem = nil
                }
            }
        }
    }

    private var customControls: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .any(of: [.images])) {
                Label(backgrounds.background == nil ? "Choose a photo or GIF" : "Change background", systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(Theme.accent)
            }
            if backgrounds.background != nil {
                Button("Remove background") { backgrounds.clear() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pick any picture from your gallery. GIFs keep moving.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Sharing

    private func share() {
        isPreparing = true
        Task {
            // Let the spinner draw before the (main-thread) rendering starts.
            try? await Task.sleep(nanoseconds: 80_000_000)
            let bg = style == .custom ? backgrounds.background : nil
            if let bg, bg.isAnimated, let url = renderGIF(bg) {
                shareItems = [url]
            } else if let url = renderPNG(still: bg?.still) {
                shareItems = [url]
            }
            isPreparing = false
            if !shareItems.isEmpty { isSharing = true }
        }
    }

    private func renderer(still: UIImage?, background: CardBackground? = nil) -> ImageRenderer<some View> {
        let view = ProfileCard(info: info, style: style, background: background, stillFrame: still)
            .padding(20)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer
    }

    private func renderPNG(still: UIImage?) -> URL? {
        guard let image = renderer(still: still).uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lockin-card.png")
        try? data.write(to: url, options: .atomic)
        return url
    }

    /// An animated GIF of the card: the picture's frames behind a still card.
    private func renderGIF(_ bg: CardBackground) -> URL? {
        let stride = max(1, Int((Double(bg.frames.count) / 24).rounded(.up)))
        let chosen = Swift.stride(from: 0, to: bg.frames.count, by: stride).map { bg.frames[$0] }
        let delay = max(0.05, bg.duration / Double(bg.frames.count) * Double(stride))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lockin-card.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, chosen.count, nil) else { return nil }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in chosen {
            let r = renderer(still: frame)
            r.scale = 2
            guard let cg = r.uiImage?.cgImage else { continue }
            CGImageDestinationAddImage(destination, cg, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        return CGImageDestinationFinalize(destination) ? url : nil
    }
}

/// The system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
