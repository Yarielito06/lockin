import Foundation
import Supabase
import UIKit

/// A photo shared with friends.
struct Moment: Identifiable, Decodable, Equatable {
    struct Reaction: Decodable, Equatable {
        let userID: UUID
        let name: String
        let emoji: String

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case name, emoji
        }
    }

    let id: UUID
    let userID: UUID
    let name: String
    let imagePath: String
    let caption: String?
    let tag: String?
    let createdAt: Date
    let reactions: [Reaction]
    /// Filled in after loading: a short-lived private link to the photo.
    var imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, caption, tag, reactions
        case userID = "user_id"
        case imagePath = "image_path"
        case createdAt = "created_at"
    }
}

/// Moments: photos you share with friends, kept for 7 days. Photos live in a private bucket
/// that only you and your friends can read (enforced on the server).
@MainActor
final class MomentsStore: ObservableObject {
    static let emojis = ["🔥", "💪", "👏", "❤️"]

    @Published private(set) var moments: [Moment] = []
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?

    private var bucket: StorageFileApi? { Backend.client?.storage.from("moments") }
    private var me: UUID? { Backend.client?.auth.currentUser?.id }

    /// Moments grouped by day, newest first.
    var days: [(day: Date, moments: [Moment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: moments) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.createdAt > $1.createdAt }) }
    }

    func isMine(_ moment: Moment) -> Bool { moment.userID == me }

    func myReaction(on moment: Moment) -> String? {
        moment.reactions.first { $0.userID == me }?.emoji
    }

    // MARK: Loading

    func refresh() async {
        guard let client = Backend.client, let bucket, client.auth.currentUser != nil else { return }
        do {
            var feed: [Moment] = try await client.rpc("moments_feed").execute().value
            guard !feed.isEmpty else {
                moments = []
                return
            }
            // Reuse links we already have so images don't reload on every refresh.
            let known = Dictionary(uniqueKeysWithValues: moments.compactMap { m in m.imageURL.map { (m.imagePath, $0) } })
            let missing = feed.map(\.imagePath).filter { known[$0] == nil }
            var urls = known
            if !missing.isEmpty {
                for result in try await bucket.createSignedURLs(paths: missing, expiresIn: 60 * 60) {
                    if case .success(let path, let url) = result { urls[path] = url }
                }
            }
            for index in feed.indices { feed[index].imageURL = urls[feed[index].imagePath] }
            moments = feed
        } catch {
            // Quiet on background refresh.
        }
    }

    // MARK: Posting

    func post(image: UIImage, caption: String, tag: String?) async -> Bool {
        guard let client = Backend.client, let bucket, let me else { return false }
        guard let data = Self.jpeg(for: image) else {
            errorMessage = "Couldn't prepare that photo."
            return false
        }
        isPosting = true
        defer { isPosting = false }
        let path = "\(me.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        do {
            _ = try await bucket.upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
            struct Params: Encodable { let image_path: String; let caption: String; let tag: String? }
            _ = try await client.rpc("post_moment", params: Params(image_path: path, caption: caption, tag: tag)).execute()
            await refresh()
            return true
        } catch {
            errorMessage = (error as? PostgrestError)?.message ?? "Couldn't share your moment. Check your connection."
            return false
        }
    }

    // MARK: Interacting

    func react(_ emoji: String, to moment: Moment) async {
        guard let client = Backend.client else { return }
        struct Params: Encodable { let mid: UUID; let emoji: String }
        _ = try? await client.rpc("react_to_moment", params: Params(mid: moment.id, emoji: emoji)).execute()
        await refresh()
    }

    func delete(_ moment: Moment) async {
        guard let client = Backend.client, let bucket else { return }
        moments.removeAll { $0.id == moment.id }
        _ = try? await client.rpc("delete_moment", params: ["mid": moment.id]).execute()
        _ = try? await bucket.remove(paths: [moment.imagePath])
    }

    func report(_ moment: Moment) async {
        guard let client = Backend.client else { return }
        moments.removeAll { $0.id == moment.id }
        struct Params: Encodable { let mid: UUID; let reason: String }
        _ = try? await client.rpc("report_moment", params: Params(mid: moment.id, reason: "Reported from app")).execute()
    }

    /// Scales to at most 1440 px on the long side and compresses, staying well under the 3 MB limit.
    private static func jpeg(for image: UIImage) -> Data? {
        let maxSide: CGFloat = 1440
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
