import SwiftUI

/// Friend requests and group invites waiting for you, plus requests you've sent.
struct PendingSection: View {
    @EnvironmentObject private var social: SocialStore

    var body: some View {
        if !social.incomingRequests.isEmpty || !social.groupInvites.isEmpty {
            VStack(spacing: 12) {
                SectionTitle("Requests")
                VStack(spacing: 0) {
                    ForEach(Array(social.incomingRequests.enumerated()), id: \.element.id) { index, request in
                        if index > 0 { Divider().padding(.leading, 56) }
                        row(
                            avatar: Avatar(name: request.name, size: 40),
                            title: request.name,
                            subtitle: "Wants to be friends"
                        ) {
                            await social.respond(to: request, accept: $0)
                        }
                    }
                    ForEach(Array(social.groupInvites.enumerated()), id: \.element.id) { index, group in
                        if index > 0 || !social.incomingRequests.isEmpty { Divider().padding(.leading, 56) }
                        row(
                            avatar: Image(systemName: "person.3.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 40, height: 40)
                                .background(Theme.background, in: Circle()),
                            title: group.name,
                            subtitle: inviteSubtitle(group)
                        ) {
                            await social.respond(toInvite: group, accept: $0)
                        }
                    }
                }
                .card(padding: 14)
            }
        }

        if !social.outgoingRequests.isEmpty {
            VStack(spacing: 12) {
                SectionTitle("Sent")
                VStack(spacing: 0) {
                    ForEach(Array(social.outgoingRequests.enumerated()), id: \.element.id) { index, person in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack(spacing: 12) {
                            Avatar(name: person.name, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name).font(.subheadline.weight(.semibold))
                                Text("Waiting for them to accept")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Cancel") {
                                Task { await social.cancelRequest(to: person) }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .card(padding: 14)
            }
        }
    }

    private func inviteSubtitle(_ group: StudyGroup) -> String {
        let count = (group.members?.filter(\.isJoined).count ?? 0)
        let people = "\(count) \(count == 1 ? "person" : "people") in it"
        return group.invitedBy.map { "\($0) invited you · \(people)" } ?? people
    }

    private func row(
        avatar: some View,
        title: String,
        subtitle: String,
        respond: @escaping (Bool) async -> Void
    ) -> some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button {
                Haptics.tap()
                Task { await respond(false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.background, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decline")
            Button {
                Haptics.success()
                Task { await respond(true) }
            } label: {
                Text("Accept")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.primary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}
