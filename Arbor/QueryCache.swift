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

    func get(for key: [String]) -> [SearchResult]? {
        return storage[key]
    }

    func set(_ value: [SearchResult], for key: [String]) {
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
    }
}
