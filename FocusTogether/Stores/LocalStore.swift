import Foundation

/// Tiny JSON-in-UserDefaults persistence for app-only data (routines, friends, history).
/// Data the extensions need lives in `SharedStore` (App Group) instead.
enum LocalStore {
    private static let defaults = UserDefaults.standard

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
        if CloudSync.isSynced(key) { CloudSync.push(key, data: data) }
    }
}
