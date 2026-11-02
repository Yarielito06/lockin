import SwiftUI

/// Name a group and pick which friends are in it.
struct NewGroupView: View {
    let onCreate: (StudyGroup) -> Void

    @EnvironmentObject private var social: SocialStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var memberIDs: Set<UUID> = []
    @State private var isCreating = false

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Library crew, Exam prep", text: $name)
                        .font(.body.weight(.medium))
                }

                Section {
                    if social.friends.isEmpty {
                        Text("Add friends in the Friends tab first.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(social.friends) { friend in
                        let isMember = memberIDs.contains(friend.id)
                        Button {
                            Haptics.select()
                            if isMember { memberIDs.remove(friend.id) } else { memberIDs.insert(friend.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Avatar(name: friend.name, size: 34, userID: friend.id)
                                Text(friend.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isMember ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isMember ? Color.primary : Color.secondary.opacity(0.4))
                            }
                        }
                    }
                } header: {
                    Text("Members")
                } footer: {
                    if social.isOnline {
                        Text("They'll get an invite and join once they accept.")
                    }
                }
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            isCreating = true
                            let ordered = social.friends.map(\.id).filter(memberIDs.contains)
                            Task {
                                if let group = await social.createGroup(named: name, memberIDs: ordered) {
                                    Haptics.success()
                                    onCreate(group)
                                    dismiss()
                                }
                                isCreating = false
                            }
                        }
                        .font(.body.weight(.semibold))
                        .disabled(!canCreate)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
