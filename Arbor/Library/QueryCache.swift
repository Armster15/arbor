//
//  QueryCache.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 10/21/25.
//

// Simple in-memory cache keyed by string arrays
final class QueryCache {
    static let shared = QueryCache()
    private init() {}

    private var storage: [[String]: Any] = [:]
    private let queue = DispatchQueue(label: "QueryCache.storage.queue", attributes: .concurrent)

    func get<T>(for key: [String], as type: T.Type = T.self) -> T? {
        var result: T?
        queue.sync {
            result = storage[key] as? T
        }
        return result
    }

    func set<T>(_ value: T, for key: [String]) {
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
