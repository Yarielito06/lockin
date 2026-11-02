import Foundation

extension Notification.Name {
    /// Newer data arrived from iCloud (another device of yours); stores reload from disk.
    static let lockinCloudApplied = Notification.Name("lockin.cloudApplied")
}

/// Keeps your routines, goals, deadlines, history and ticks the same on every device signed in to
/// your iCloud account (iPhone and Mac), using iCloud's small key-value store. No account to make.
/// Newest write wins; history and ticks are merged so nothing is lost.
enum CloudSync {
    /// What syncs, and how.
    static let replaced: Set<String> = ["lockin.routines", "lockin.planItems", "lockin.goals"]
    static let historyKey = "lockin.sessionHistory"
    static let completionsKey = "lockin.cloudCompletions"
    private static var allKeys: [String] { Array(replaced) + [historyKey, completionsKey] }

    private static let store = NSUbiquitousKeyValueStore.default
    private static let local = UserDefaults.standard
    /// Set while writing data that came *from* iCloud, so it isn't sent straight back.
    static var isApplying = false
    private static var started = false

    static func isSynced(_ key: String) -> Bool {
        replaced.contains(key) || key == historyKey
    }

    // MARK: Sending

    static func push(_ key: String, data: Data) {
        guard !isApplying else { return }
        store.set(data, forKey: key)
        store.set(Date().timeIntervalSince1970, forKey: stampKey(key))
        local.set(Date().timeIntervalSince1970, forKey: stampKey(key))
        store.synchronize()
    }

    // MARK: Receiving

    /// Call once at launch. Pulls newer data, and seeds iCloud from this device if it's empty there.
    static func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil, queue: .main
        ) { note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? allKeys
            apply(keys)
        }
        store.synchronize()
        apply(allKeys)
        // First device to run: put what it has into iCloud.
        for key in allKeys where store.data(forKey: key) == nil {
            if let data = key == completionsKey ? completionsData() : local.data(forKey: key), data.count > 2 {
                push(key, data: data)
            }
        }
    }

    private static func apply(_ keys: [String]) {
        var changed = false
        for key in keys where allKeys.contains(key) {
            guard let remote = store.data(forKey: key) else { continue }
            let remoteStamp = store.double(forKey: stampKey(key))
            let localStamp = local.double(forKey: stampKey(key))

            switch key {
            case historyKey:
                if mergeHistory(remote) { changed = true }
            case completionsKey:
                if mergeCompletions(remote) { changed = true }
            default:
                guard remoteStamp > localStamp, remote != local.data(forKey: key) else { continue }
                isApplying = true
                local.set(remote, forKey: key)
                local.set(remoteStamp, forKey: stampKey(key))
                isApplying = false
                changed = true
            }
        }
        if changed {
            isApplying = true
            NotificationCenter.default.post(name: .lockinCloudApplied, object: nil)
            isApplying = false
        }
    }

    // MARK: Merging

    private struct HistoryEntry: Codable { var id: UUID }

    /// Sessions from both devices, each kept once.
    private static func mergeHistory(_ remote: Data) -> Bool {
        guard let remoteItems = try? JSONSerialization.jsonObject(with: remote) as? [[String: Any]] else { return false }
        let localItems = (local.data(forKey: historyKey).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }) ?? []
        var byID: [String: [String: Any]] = [:]
        for item in localItems + remoteItems { if let id = item["id"] as? String { byID[id] = item } }
        guard byID.count != localItems.count else { return false }
        let merged = Array(byID.values)
        guard let data = try? JSONSerialization.data(withJSONObject: merged) else { return false }
        isApplying = true
        local.set(data, forKey: historyKey)
        isApplying = false
        return true
    }

    private static func completionsData() -> Data? {
        try? JSONEncoder().encode(SharedCompletions.load())
    }

    /// Ticks from both devices: a day's done-set is the union.
    private static func mergeCompletions(_ remote: Data) -> Bool {
        guard let remoteDays = try? JSONDecoder().decode(SharedCompletions.Days.self, from: remote) else { return false }
        var days = SharedCompletions.load()
        var changed = false
        for (day, done) in remoteDays {
            let merged = days[day, default: []].union(done)
            if merged != days[day] { days[day] = merged; changed = true }
        }
        if changed { SharedCompletions.save(days) }
        return changed
    }

    private static func stampKey(_ key: String) -> String { "lockin.cloudStamp.\(key)" }
}
