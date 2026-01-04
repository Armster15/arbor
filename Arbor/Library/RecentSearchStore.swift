import Foundation

struct RecentSearchEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let artists: [String]
    let originalUrl: String
    let thumbnailUrl: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let thumbnailIsSquare: Bool?
    let provider: SearchProvider
    let createdAt: Date
}

enum RecentSearchStore {
    private static let storageKey = "recentSearches"
    private static let limit = 12

    static func load(from defaults: UserDefaults = .standard) -> [RecentSearchEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([RecentSearchEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func save(_ entries: [RecentSearchEntry], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func add(libraryItem: LibraryItem, provider: SearchProvider, to entries: [RecentSearchEntry]) -> [RecentSearchEntry] {
        let trimmedTitle = libraryItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = libraryItem.original_url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedURL.isEmpty else { return entries }

        let normalized = normalizedKey(url: trimmedURL, provider: provider)
        let filtered = entries.filter { entry in
            normalizedKey(url: entry.originalUrl, provider: entry.provider) != normalized
        }

        let newEntry = RecentSearchEntry(
            id: UUID(),
            title: trimmedTitle,
            artists: libraryItem.artists,
            originalUrl: trimmedURL,
            thumbnailUrl: libraryItem.thumbnail_url,
            thumbnailWidth: libraryItem.thumbnail_width,
            thumbnailHeight: libraryItem.thumbnail_height,
            thumbnailIsSquare: libraryItem.thumbnail_is_square,
            provider: provider,
            createdAt: Date()
        )

        return Array(([newEntry] + filtered).prefix(limit))
    }

    private static func normalizedKey(url: String, provider: SearchProvider) -> String {
        let cleaned = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(provider.rawValue)|\(cleaned)"
    }
}
