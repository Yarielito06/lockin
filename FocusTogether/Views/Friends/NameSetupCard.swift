import SwiftUI

/// First visit to Friends when connected: pick the name friends will see.
struct NameSetupCard: View {
    @EnvironmentObject private var social: SocialStore
    @State private var name = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should friends call you?")
                    .font(.title3.bold())
                Text("Friends see this name and when you're locked in. Nothing else.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Your name", text: $name)
                .focused($isFocused)
                .textContentType(.givenName)
                .submitLabel(.done)
                .onSubmit(save)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.background, in: Capsule())

            Button(action: save) {
                if isSaving {
                    ProgressView().tint(Theme.background)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.primary)
            .disabled(!canSave)
        }
        .card(padding: 20)
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            await social.setName(name)
            isSaving = false
            if social.me != nil { Haptics.success() }
        }
    }
}
