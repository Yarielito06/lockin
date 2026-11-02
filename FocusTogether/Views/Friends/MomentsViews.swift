import PhotosUI
import SwiftUI

// MARK: - Feed

/// Friends' moments from the last 7 days, grouped by day, plus a "Share a moment" card.
struct MomentsFeed: View {
    @EnvironmentObject private var moments: MomentsStore
    @State private var isComposing = false
    @State private var viewing: Moment?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            shareCard

            if moments.moments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No moments this week yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Share your desk, your view, your finished workout — your friends will see it here for 7 days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(moments.days, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(dayTitle(group.day))
                            .font(.headline)
                        ForEach(group.moments) { moment in
                            MomentCard(moment: moment) { viewing = moment }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isComposing) { MomentComposer() }
        .fullScreenCover(item: $viewing) { MomentViewer(moment: $0) }
        .task { await moments.refresh() }
    }

    private var shareCard: some View {
        Button {
            Haptics.tap()
            isComposing = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Theme.accent, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share a moment").font(.headline)
                    Text("Show your friends what you're up to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .card(padding: 16)
        }
        .buttonStyle(.plain)
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}

/// One moment: who, when, the photo, its tag and caption, and reactions.
private struct MomentCard: View {
    let moment: Moment
    let onOpen: () -> Void

    @EnvironmentObject private var moments: MomentsStore
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Avatar(name: moment.name, size: 34, isMe: moments.isMine(moment))
                VStack(alignment: .leading, spacing: 1) {
                    Text(moments.isMine(moment) ? "You" : moment.name)
                        .font(.subheadline.weight(.semibold))
                    Text(moment.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    if moments.isMine(moment) {
                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Label("Delete moment", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            Task { await moments.report(moment) }
                        } label: {
                            Label("Report and hide", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .tint(.secondary)
            }

            Button(action: onOpen) {
                Color.clear
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .overlay { MomentImage(url: moment.imageURL) }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        if let tag = moment.tag {
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(10)
                        }
                    }
            }
            .buttonStyle(.plain)

            if let caption = moment.caption {
                Text(caption)
                    .font(.subheadline)
            }

            ReactionBar(moment: moment)
        }
        .card(padding: 14)
        .confirmationDialog("Delete this moment?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await moments.delete(moment) } }
        }
    }
}

/// 🔥 💪 👏 ❤️ — tap to react (tap again to remove), with who reacted.
private struct ReactionBar: View {
    let moment: Moment
    @EnvironmentObject private var moments: MomentsStore

    var body: some View {
        let mine = moments.myReaction(on: moment)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(MomentsStore.emojis, id: \.self) { emoji in
                    let count = moment.reactions.filter { $0.emoji == emoji }.count
                    Button {
                        Haptics.tap()
                        Task { await moments.react(emoji, to: moment) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(emoji)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            Capsule().fill(mine == emoji ? Theme.accent.opacity(0.18) : Theme.background)
                        )
                        .overlay(Capsule().strokeBorder(mine == emoji ? Theme.accent : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("React \(emoji)")
                }
            }
            if !moment.reactions.isEmpty {
                Text(moment.reactions.map { "\($0.emoji) \(moments.isMine(moment) && $0.userID == moment.userID ? "You" : $0.name)" }
                    .joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// Loads a moment's photo from its private link.
private struct MomentImage: View {
    let url: URL?
    var fill = true

    var body: some View {
        ZStack {
            Rectangle().fill(fill ? Theme.track : .clear)
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        if fill {
                            image.resizable().scaledToFill()
                        } else {
                            image.resizable().scaledToFit()
                        }
                    case .failure:
                        Image(systemName: "photo").font(.title).foregroundStyle(.tertiary)
                    default:
                        ProgressView()
                    }
                }
            }
        }
    }
}

// MARK: - Viewer

/// Full-screen photo with caption.
private struct MomentViewer: View {
    let moment: Moment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            MomentImage(url: moment.imageURL, fill: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 10) {
                Avatar(name: moment.name, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(moment.name).font(.subheadline.weight(.semibold))
                    Text(moment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .opacity(0.7)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Close")
            }
            .foregroundStyle(.white)
            .padding()
        }
        .overlay(alignment: .bottom) {
            if moment.caption != nil || moment.tag != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let tag = moment.tag {
                        Text(tag).font(.caption.weight(.semibold))
                    }
                    if let caption = moment.caption {
                        Text(caption).font(.body)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            }
        }
        .gesture(DragGesture().onEnded { if $0.translation.height > 80 { dismiss() } })
    }
}

// MARK: - Composer

/// Pick or take a photo, add a caption and an optional tag from your day, and share.
struct MomentComposer: View {
    @EnvironmentObject private var moments: MomentsStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var routines: RoutineStore
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var caption = ""
    @State private var tag: String?

    /// Tags drawn from today: focus time, streak, completed routines.
    private var suggestedTags: [String] {
        var tags: [String] = []
        if history.todayMinutes > 0 { tags.append("🔒 Locked in \(history.todayMinutes.minutesLabel)") }
        if history.streakDays > 1 { tags.append("🔥 \(history.streakDays)-day streak") }
        for routine in routines.routines {
            let due = routines.dueSlots(in: routine).count
            if due > 0, routines.doneCount(in: routine) == due {
                tags.append("✅ \(routine.name) \(due)/\(due)")
            }
        }
        tags.append("📚 Studying")
        tags.append("💪 Workout done")
        return Array(tags.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photoArea

                    TextField("Say something… (optional)", text: $caption, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: caption) { caption = String($0.prefix(140)) }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add a tag").font(.headline)
                        FlowTags(tags: suggestedTags, selected: $tag)
                    }
                }
                .padding(Theme.gutter)
            }
            .navigationTitle("New moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if moments.isPosting {
                        ProgressView()
                    } else {
                        Button("Share", action: share)
                            .font(.body.weight(.semibold))
                            .disabled(image == nil)
                    }
                }
            }
            .onChange(of: pickerItem) { item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                        image = picked
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker(image: $image).ignoresSafeArea()
            }
            .alert(
                "Moments",
                isPresented: Binding(get: { moments.errorMessage != nil }, set: { if !$0 { moments.errorMessage = nil } }),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(moments.errorMessage ?? "") }
            )
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        if let image {
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button { self.image = nil } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .padding(10)
                    .accessibilityLabel("Remove photo")
                }
                .overlay(alignment: .bottomLeading) {
                    if let tag {
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(10)
                    }
                }
        } else {
            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    sourceButton("Camera", symbol: "camera.fill") { isShowingCamera = true }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    sourceTile("Library", symbol: "photo.on.rectangle")
                }
                .buttonStyle(.plain)
            }
            .frame(height: 180)
        }
    }

    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { sourceTile(title, symbol: symbol) }
            .buttonStyle(.plain)
    }

    private func sourceTile(_ title: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
            Text(title).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func share() {
        guard let image else { return }
        Task {
            if await moments.post(image: image, caption: caption, tag: tag) {
                Haptics.success()
                dismiss()
            }
        }
    }
}

/// Tag chips that wrap onto new lines.
private struct FlowTags: View {
    let tags: [String]
    @Binding var selected: String?

    var body: some View {
        // Simple two-column layout keeps chips aligned without a custom Layout.
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let isOn = selected == tag
                Button {
                    Haptics.select()
                    selected = isOn ? nil : tag
                } label: {
                    Text(tag)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isOn ? Theme.background : .primary)
                        .background(isOn ? Color.primary : Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The system camera, for taking a moment's photo.
private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
