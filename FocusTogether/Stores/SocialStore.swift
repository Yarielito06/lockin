import Combine
import Foundation
import Supabase

/// Friends, requests, groups and your profile.
///
/// With a Supabase project configured (`Backend.client`), you sign in anonymously, get a real
/// invite code, send and accept friend requests, create groups that friends accept, and see
/// group lock-ins you can join. Without one, the app runs on on-device sample friends and
/// local groups so the UI still works.
@MainActor
final class SocialStore: ObservableObject {
    private enum Key {
        static let friends = "lockin.friends"
        static let groups = "lockin.groups"
        static let inviteCode = "lockin.inviteCode"
    }

    @Published private(set) var friends: [Friend] {
        didSet { LocalStore.save(friends, forKey: Key.friends) }
    }

    /// Groups you're in (joined).
    @Published private(set) var groups: [StudyGroup] {
        didSet { LocalStore.save(groups, forKey: Key.groups) }
    }

    @Published private(set) var incomingRequests: [PersonRef] = []
    @Published private(set) var outgoingRequests: [PersonRef] = []
    /// Groups you've been invited to but haven't answered.
    @Published private(set) var groupInvites: [StudyGroup] = []

    /// Your profile on the server; nil until signed in and named.
    @Published private(set) var me: ProfileRow?
    /// True once we've checked the server, so the UI can tell "loading" from "needs a name".
    @Published private(set) var hasLoadedProfile = false
    @Published var errorMessage: String?

    /// Group sessions you've chosen not to join (group id + end time), so the prompt stays away.
    @Published private var dismissedSessions: Set<String> = []

    var isOnline: Bool { Backend.client != nil }
    var needsName: Bool { isOnline && hasLoadedProfile && me == nil }
    var hasSampleFriends: Bool { friends.contains(where: \.isSample) }

    /// Requests and invites waiting for you — shown as a badge on the Friends tab.
    var pendingCount: Int { incomingRequests.count + groupInvites.count }

    /// Your shareable code: the server's when online, a local placeholder otherwise.
    var inviteCode: String { me?.inviteCode ?? localInviteCode }

    private let localInviteCode: String
    private var lastPublished: ProfileStatusUpdate?
    private weak var blocking: BlockingManager?
    private weak var history: HistoryStore?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let cached = LocalStore.load([Friend].self, forKey: Key.friends)
        let cachedGroups = LocalStore.load([StudyGroup].self, forKey: Key.groups) ?? []

        if let code = UserDefaults.standard.string(forKey: Key.inviteCode) {
            localInviteCode = code
        } else {
            let code = Self.makeLocalCode()
            UserDefaults.standard.set(code, forKey: Key.inviteCode)
            localInviteCode = code
        }

        if Backend.client != nil {
            // Real friends and server groups only; drop demo data and groups made on-device.
            friends = (cached ?? []).filter { !$0.isSample }
            groups = cachedGroups.filter { $0.members != nil }
            Task { await connect() }
        } else {
            friends = cached ?? Friend.samples
            groups = cachedGroups
            refreshSampleStatuses()
        }
    }

    func friendsFocusing(at date: Date) -> [Friend] {
        friends.filter { $0.isFocusing(at: date) }.sorted { $0.minutesLeft(at: date) < $1.minutesLeft(at: date) }
    }

    // MARK: Server

    /// Signs in (anonymously, once per install) and loads your profile and everything social.
    func connect() async {
        guard let client = Backend.client else { return }
        do {
            if client.auth.currentSession == nil {
                try await client.auth.signInAnonymously()
            }
            guard let userID = client.auth.currentUser?.id else { return }
            let rows: [ProfileRow] = try await client.from("profiles").select().eq("id", value: userID).execute().value
            me = rows.first
            hasLoadedProfile = true
            if me != nil {
                await PushRegistration.upload()
                await refresh()
                await publishCurrent()
                startRealtime()
            }
        } catch {
            report(error)
        }
    }

    /// Creates your profile (first time) or renames you.
    func setName(_ name: String) async {
        guard let client = Backend.client, let userID = client.auth.currentUser?.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            if me == nil {
                struct NewProfile: Encodable {
                    let id: UUID
                    let display_name: String
                }
                me = try await client.from("profiles")
                    .insert(NewProfile(id: userID, display_name: trimmed))
                    .select().single().execute().value
                // First time on Friends: allow alerts so requests and group lock-ins can reach you.
                await ReminderScheduler.requestPermission()
                await PushRegistration.upload()
            } else {
                me = try await client.from("profiles")
                    .update(["display_name": trimmed]).eq("id", value: userID)
                    .select().single().execute().value
            }
            await refresh()
            startRealtime()
        } catch {
            report(error)
        }
    }

    /// Points your profile at an uploaded photo (nil removes it).
    func setAvatarPath(_ path: String?) async throws {
        guard let client = Backend.client, let userID = me?.id else { return }
        struct Update: Encodable {
            let avatar_path: String?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(avatar_path, forKey: .avatar_path)
            }
            enum CodingKeys: String, CodingKey { case avatar_path }
        }
        me = try await client.from("profiles").update(Update(avatar_path: path)).eq("id", value: userID)
            .select().single().execute().value
    }

    /// Reloads friends, requests, groups and invites. Called on a timer while the app is open.
    func refresh() async {
        guard let client = Backend.client, me != nil else { return }
        do {
            async let friendRows: [ProfileRow] = client.rpc("my_friends").execute().value
            async let social: SocialSnapshot = client.rpc("my_social").execute().value
            let (rows, snapshot) = try await (friendRows, social)
            friends = rows.map(\.asFriend)
            incomingRequests = snapshot.incoming
            outgoingRequests = snapshot.outgoing
            groups = snapshot.groups.map { $0.asGroup(me: me?.id) }
            groupInvites = snapshot.invites.map { $0.asGroup(me: me?.id) }
        } catch {
            // Background refreshes stay quiet; actions report their own errors.
        }
    }

    // MARK: Friend requests

    /// Sends a request to the owner of an invite code. Returns a message for the user.
    func sendRequest(code: String) async -> String? {
        guard let client = Backend.client else { return nil }
        do {
            let result: FriendRequestResult = try await client
                .rpc("send_friend_request", params: ["code": code.trimmingCharacters(in: .whitespaces).uppercased()])
                .execute().value
            await refresh()
            switch result.status {
            case "accepted": return "You and \(result.name) are now friends"
            case "already": return "You're already friends with \(result.name)"
            default: return "Request sent to \(result.name)"
            }
        } catch {
            report(error)
            return nil
        }
    }

    func respond(to request: PersonRef, accept: Bool) async {
        guard let client = Backend.client else { return }
        incomingRequests.removeAll { $0.id == request.id }
        do {
            struct Params: Encodable { let requester: UUID; let accept: Bool }
            try await client.rpc("respond_friend_request", params: Params(requester: request.id, accept: accept)).execute()
        } catch {
            report(error)
        }
        await refresh()
    }

    func cancelRequest(to person: PersonRef) async {
        guard let client = Backend.client else { return }
        outgoingRequests.removeAll { $0.id == person.id }
        do {
            try await client.rpc("cancel_friend_request", params: ["target": person.id]).execute()
        } catch {
            report(error)
        }
    }

    // MARK: Live status

    /// Shares your live status with friends. Called when a session starts or ends and when stats change.
    func publish(session: FocusSession?, weekMinutes: Int, streak: Int) async {
        guard let client = Backend.client, let userID = me?.id else { return }
        let update = ProfileStatusUpdate(
            focusingUntil: session?.endDate,
            focusGroup: session?.groupName,
            focusSince: session?.startDate,
            focusOpen: session?.isOpenEnded ?? false,
            weekMinutes: weekMinutes,
            weekStart: Backend.currentWeekKey(),
            streak: streak
        )
        if let lastPublished, lastPublished.sameStatus(as: update) { return }
        do {
            try await client.from("profiles").update(update).eq("id", value: userID).execute()
            lastPublished = update
        } catch {
            report(error)
        }
    }

    /// Republishes your status whenever the session or history changes.
    func observe(blocking: BlockingManager, history: HistoryStore) {
        self.blocking = blocking
        self.history = history
        Publishers.Merge(blocking.objectWillChange, history.objectWillChange)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self, weak blocking, weak history] _ in
                guard let self, let blocking, let history else { return }
                Task { await self.publish(session: blocking.activeSession, weekMinutes: history.weekMinutes, streak: history.streakDays) }
            }
            .store(in: &cancellables)
    }

    /// Uploads your status right now. Needed because a change made before you were signed in
    /// (a session that finished while the app was closed) never triggers the observer above.
    func publishCurrent() async {
        guard let blocking, let history else { return }
        await publish(session: blocking.activeSession, weekMinutes: history.weekMinutes, streak: history.streakDays)
    }

    // MARK: Live updates

    /// Bumped whenever a cheer arrives, so open screens can reload at once.
    @Published private(set) var cheerPing = 0
    private var realtimeTask: Task<Void, Never>?

    /// Listens for friends' status changes and cheers, so they show up without waiting for the next refresh.
    private func startRealtime() {
        guard let client = Backend.client, let myID = me?.id, realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            let channel = client.realtimeV2.channel("lockin-live")
            let profileChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "profiles")
            let cheerInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "cheers", filter: "to_id=eq.\(myID.uuidString.lowercased())")
            do {
                try await channel.subscribeWithError()
            } catch {
                await MainActor.run { self?.realtimeTask = nil }
                return
            }
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    var last = Date.distantPast
                    for await _ in profileChanges {
                        // A burst of changes needs only one reload.
                        guard Date().timeIntervalSince(last) > 1 else { continue }
                        last = Date()
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        await self?.refresh()
                    }
                }
                group.addTask {
                    for await _ in cheerInserts {
                        await MainActor.run { self?.cheerPing += 1 }
                    }
                }
            }
        }
    }

    // MARK: Cheers

    /// Cheers received during your current session, newest first.
    @Published private(set) var cheers: [Cheer] = []

    /// Sends a cheer to a friend who's locked in. Returns an error message, or nil on success.
    func cheer(_ friend: Friend, emoji: String) async -> String? {
        guard let client = Backend.client else { return nil }
        do {
            struct Params: Encodable { let target: UUID; let emoji: String }
            try await client.rpc("send_cheer", params: Params(target: friend.id, emoji: emoji)).execute()
            return nil
        } catch {
            return (error as? PostgrestError)?.message ?? "Couldn't send that. Check your connection."
        }
    }

    /// Loads the cheers you've received since `date`. Returns true when new ones arrived.
    @discardableResult
    func refreshCheers(since date: Date) async -> Bool {
        guard let client = Backend.client, me != nil else { return false }
        do {
            struct Params: Encodable { let since: Date }
            let loaded: [Cheer] = try await client.rpc("my_cheers", params: Params(since: date)).execute().value
            let isNew = loaded.contains { c in !cheers.contains { $0.id == c.id } }
            cheers = loaded
            return isNew
        } catch {
            return false
        }
    }

    // MARK: Friends

    /// Offline mode only: adds a friend by name to the on-device list.
    func addLocalFriend(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        friends.append(Friend(name: trimmed))
    }

    func remove(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        guard let client = Backend.client, !friend.isSample else {
            groups = groups.map { group in
                var group = group
                group.memberIDs.removeAll { $0 == friend.id }
                return group
            }
            return
        }
        Task {
            do {
                try await client.rpc("remove_friend", params: ["friend": friend.id]).execute()
            } catch {
                report(error)
            }
        }
    }

    // MARK: Groups

    /// Creates a group. Online, the chosen friends get an invite they have to accept.
    func createGroup(named name: String, memberIDs: [UUID]) async -> StudyGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client = Backend.client else {
            let group = StudyGroup(name: trimmed, memberIDs: memberIDs)
            groups.append(group)
            return group
        }
        do {
            struct Params: Encodable { let group_name: String; let member_ids: [UUID] }
            let id: UUID = try await client.rpc("create_group", params: Params(group_name: trimmed, member_ids: memberIDs)).execute().value
            await refresh()
            return groups.first { $0.id == id }
        } catch {
            report(error)
            return nil
        }
    }

    /// Leaves a group (online) or deletes it (offline).
    func delete(_ group: StudyGroup) {
        groups.removeAll { $0.id == group.id }
        guard let client = Backend.client else { return }
        Task {
            do {
                try await client.rpc("leave_group", params: ["gid": group.id]).execute()
            } catch {
                report(error)
            }
        }
    }

    func respond(toInvite group: StudyGroup, accept: Bool) async {
        guard let client = Backend.client else { return }
        groupInvites.removeAll { $0.id == group.id }
        do {
            struct Params: Encodable { let gid: UUID; let accept: Bool }
            try await client.rpc("respond_group_invite", params: Params(gid: group.id, accept: accept)).execute()
        } catch {
            report(error)
        }
        await refresh()
    }

    /// Tells the group you've started a lock-in, so members' apps offer to join.
    func announceGroupSession(_ group: StudyGroup, endsAt: Date) async {
        guard let client = Backend.client else { return }
        do {
            struct Params: Encodable { let gid: UUID; let ends_at: Date }
            try await client.rpc("start_group_session", params: Params(gid: group.id, ends_at: endsAt)).execute()
            await refresh()
        } catch {
            report(error)
        }
    }

    /// A group lock-in someone else started that you could join right now.
    func joinableGroupSession(at date: Date) -> StudyGroup? {
        groups.first { group in
            group.isSessionRunning(at: date)
                && group.sessionStartedBy != me?.id
                && !dismissedSessions.contains(Self.sessionKey(group))
        }
    }

    func dismissGroupSession(_ group: StudyGroup) {
        dismissedSessions.insert(Self.sessionKey(group))
    }

    /// Joined members other than you, as friends (for avatars and "locked in" status).
    func members(of group: StudyGroup) -> [Friend] {
        if let members = group.members {
            return members
                .filter { $0.isJoined && $0.id != me?.id }
                .map { Friend(id: $0.id, name: $0.name, focusingUntil: $0.focusingUntil) }
        }
        return group.memberIDs.compactMap { id in friends.first { $0.id == id } }
    }

    /// Members still deciding on an invite.
    func invitedMembers(of group: StudyGroup) -> [GroupMember] {
        group.members?.filter { !$0.isJoined } ?? []
    }

    func group(named name: String) -> StudyGroup? {
        groups.first { $0.name == name }
    }

    // MARK: Private

    private static func sessionKey(_ group: StudyGroup) -> String {
        "\(group.id)-\(group.sessionEndsAt?.timeIntervalSince1970 ?? 0)"
    }

    private func report(_ error: Error) {
        // Postgres exceptions raised in the functions come back with a readable message.
        if let postgrest = error as? PostgrestError {
            errorMessage = postgrest.message
        } else if (error as? URLError) != nil {
            errorMessage = "You're offline. Friends will update when you're back online."
        } else {
            errorMessage = error.localizedDescription
        }
    }

    /// Gives the demo friends a fresh "locked in" status each launch so the UI has something to show.
    private func refreshSampleStatuses() {
        let now = Date()
        friends = friends.map { friend in
            guard friend.isSample else { return friend }
            var friend = friend
            friend.focusingUntil = friend.demoFocusMinutes.map { now.addingTimeInterval(TimeInterval($0 * 60)) }
            return friend
        }
    }

    private static func makeLocalCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return "LOCK-" + String((0..<5).map { _ in alphabet.randomElement()! })
    }
}
