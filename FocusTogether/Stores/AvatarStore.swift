import Foundation
import Supabase
import UIKit

/// Profile photos: yours and your friends'. Files live in your folder of the private `moments`
/// bucket, so only you and your friends can load them.
@MainActor
final class AvatarStore: ObservableObject {
    @Published private(set) var images: [UUID: UIImage] = [:]
    @Published var errorMessage: String?
    @Published private(set) var isUploading = false

    private var loadedPaths: [UUID: String] = [:]
    private var bucket: StorageFileApi? { Backend.client?.storage.from("moments") }

    func image(for id: UUID?) -> UIImage? {
        id.flatMap { images[$0] }
    }

    /// Loads any photo that's new or changed. Called whenever friends refresh.
    func sync(me: ProfileRow?, friends: [Friend]) async {
        var wanted: [(UUID, String?)] = friends.map { ($0.id, $0.avatarPath) }
        if let me { wanted.append((me.id, me.avatarPath)) }
        for (id, path) in wanted {
            guard let path else {
                images[id] = nil
                loadedPaths[id] = nil
                continue
            }
            guard loadedPaths[id] != path, let bucket else { continue }
            do {
                let url = try await bucket.createSignedURL(path: path, expiresIn: 3600)
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    images[id] = image
                    loadedPaths[id] = path
                }
            } catch {
                // Try again on the next refresh.
            }
        }
    }

    /// Crops to a square, uploads and points your profile at the new photo.
    func setPhoto(_ image: UIImage, social: SocialStore) async {
        guard let bucket, let me = social.me, let data = Self.squareJPEG(image) else { return }
        isUploading = true
        defer { isUploading = false }
        let path = "\(me.id.uuidString.lowercased())/avatar-\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            _ = try await bucket.upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
            let old = me.avatarPath
            try await social.setAvatarPath(path)
            images[me.id] = UIImage(data: data)
            loadedPaths[me.id] = path
            if let old { _ = try? await bucket.remove(paths: [old]) }
        } catch {
            errorMessage = "Couldn't save your photo. Check your connection."
        }
    }

    func removePhoto(social: SocialStore) async {
        guard let bucket, let me = social.me, let old = me.avatarPath else { return }
        do {
            try await social.setAvatarPath(nil)
            images[me.id] = nil
            loadedPaths[me.id] = nil
            _ = try? await bucket.remove(paths: [old])
        } catch {
            errorMessage = "Couldn't remove your photo."
        }
    }

    private static func squareJPEG(_ image: UIImage) -> Data? {
        let side = min(image.size.width, image.size.height)
        let target: CGFloat = 480
        let scale = target / side
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format).image { _ in
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (target - size.width) / 2, y: (target - size.height) / 2, width: size.width, height: size.height))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }
}
