import SwiftUI

/// Share your invite code, and add a friend with theirs (or by name when offline).
struct AddFriendView: View {
    @EnvironmentObject private var social: SocialStore
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var isAdding = false
    @State private var resultMessage: String?
    @State private var isAddingNearby = false
    @FocusState private var isInputFocused: Bool

    private var canAdd: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isAdding
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if social.isOnline, social.me != nil {
                    Button { isAddingNearby = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.background)
                                .frame(width: 44, height: 44)
                                .background(Color.primary, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add nearby").font(.headline)
                                Text("Hold your phones together")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                        .card(padding: 16)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 14) {
                    Text("Your invite code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(social.inviteCode)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    ShareLink(item: "Lock in with me on Lockin. Add me with the code \(social.inviteCode)") {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .card(padding: 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text(social.isOnline ? "Send a request with their code" : "Add by name")
                        .font(.headline)
                    HStack(spacing: 10) {
                        TextField(social.isOnline ? "LOCK-XXXXX" : "Friend's name", text: $input)
                            .focused($isInputFocused)
                            .textInputAutocapitalization(social.isOnline ? .characters : .words)
                            .autocorrectionDisabled(social.isOnline)
                            .font(social.isOnline ? .body.monospaced() : .body)
                            .submitLabel(.done)
                            .onSubmit(add)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Theme.surface, in: Capsule())
                        Button(action: add) {
                            if isAdding {
                                ProgressView().tint(Theme.background)
                            } else {
                                Text("Add")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(canAdd ? Theme.background : Color.secondary)
                        .frame(width: 72, height: 50)
                        .background(canAdd ? Color.primary : Theme.surface, in: Capsule())
                        .disabled(!canAdd)
                    }
                    if let resultMessage {
                        Label(resultMessage, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                    }
                    if let error = social.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .padding(Theme.gutter)
            .navigationTitle("Add friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $isAddingNearby) {
            AddNearbyView(name: social.me?.displayName ?? "Lockin friend", code: social.inviteCode) { code in
                await social.sendRequest(code: code)
            }
        }
    }

    private func add() {
        guard canAdd else { return }
        if !social.isOnline {
            Haptics.success()
            social.addLocalFriend(named: input)
            dismiss()
            return
        }
        isAdding = true
        resultMessage = nil
        social.errorMessage = nil
        Task {
            if let message = await social.sendRequest(code: input) {
                Haptics.success()
                resultMessage = message
                input = ""
            }
            isAdding = false
        }
    }
}
