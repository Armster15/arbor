//
//  QueryCache.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 10/21/25.
//

// Simple in-memory cache for search results keyed by string arrays
final class QueryCache {
    static let shared = QueryCache()
    private init() {}

    private var storage: [[String]: [SearchResult]] = [:]
    private let queue = DispatchQueue(label: "QueryCache.storage.queue", attributes: .concurrent)

    func get(for key: [String]) -> [SearchResult]? {
        var result: [SearchResult]?
        queue.sync {
            result = storage[key]
        }
        return result
    }

    func set(_ value: [SearchResult], for key: [String]) {
        queue.sync(flags: .barrier) {
            storage[key] = value
        }
    }

    func clear() {
        queue.sync(flags: .barrier) {
            storage.removeAll()
        }
    }

    func invalidateQueries(_ prefix: [String]) {
        guard !prefix.isEmpty else { return }
        queue.sync(flags: .barrier) {
            let keysToRemove = storage.keys.filter { key in
                key.starts(with: prefix)
            }
            for key in keysToRemove {
                storage.removeValue(forKey: key)
            }
        }
    }
}
