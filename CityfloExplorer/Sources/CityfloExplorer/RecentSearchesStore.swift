import Foundation

// Persists recent searches across launches using UserDefaults.
// Decision: max 10 entries, most-recent-first, case-insensitive deduplication.
// Actor isolation prevents races between a search write and a concurrent fetch.
actor RecentSearchesStore {

    private let key = "recent_searches"
    private let maxCount = 10

    func all() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var existing = all()
        // Deduplicate case-insensitively, remove any prior occurrence
        existing.removeAll { $0.lowercased() == trimmed.lowercased() }
        existing.insert(trimmed, at: 0)
        if existing.count > maxCount { existing = Array(existing.prefix(maxCount)) }
        UserDefaults.standard.set(existing, forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
