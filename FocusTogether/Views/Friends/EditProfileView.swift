import PhotosUI
import SwiftUI

/// Change your name and profile photo.
struct EditProfileView: View {
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var avatars: AvatarStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty && !isSaving && !avatars.isUploading }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 14) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            photo
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 18) {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Text(avatars.image(for: social.me?.id) == nil ? "Add photo" : "Change photo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            if social.me?.avatarPath != nil {
                                Button("Remove") { Task { await avatars.removePhoto(social: social) } }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Your name", text: $name)
                            .focused($isNameFocused)
                            .textContentType(.givenName)
                            .submitLabel(.done)
                            .onChange(of: name) { name = String($0.prefix(40)) }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("Friends see this name and your photo. Nothing else is shared.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(!canSave)
                }
            }
            .onAppear { name = social.me?.displayName ?? "" }
            .onChange(of: pickerItem) { item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                    await avatars.setPhoto(image, social: social)
                    pickerItem = nil
                }
            }
            .alert(
                "Profile",
                isPresented: Binding(get: { avatars.errorMessage != nil }, set: { if !$0 { avatars.errorMessage = nil } }),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(avatars.errorMessage ?? "") }
            )
        }
        .presentationDetents([.large])
    }

    private var photo: some View {
        ZStack {
            if let image = avatars.image(for: social.me?.id) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Avatar(name: social.me?.displayName ?? "You", size: 120, isMe: true)
            }
            if avatars.isUploading {
                Color.black.opacity(0.35)
                ProgressView().tint(.white)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.accent, in: Circle())
                .overlay(Circle().stroke(Theme.background, lineWidth: 3))
        }
    }

    private func save() {
        isSaving = true
        Task {
            if trimmed != social.me?.displayName { await social.setName(trimmed) }
            isSaving = false
            Haptics.success()
            dismiss()
        }
    }
}

/// Your avatar: your photo when you have one, otherwise your initials.
struct MyAvatar: View {
    let size: CGFloat
    @EnvironmentObject private var social: SocialStore
    @EnvironmentObject private var avatars: AvatarStore

    var body: some View {
        if let image = avatars.image(for: social.me?.id) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Avatar(name: social.me?.displayName ?? "You", size: size, isMe: true)
        }
    }
}
