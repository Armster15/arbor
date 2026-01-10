import Foundation

struct LyricsPayload: Codable, Equatable {
    let timed: Bool
    let lines: [LyricsLine]
}

struct LyricsLine: Codable, Equatable {
    let startMs: Int?
    let text: String

    enum CodingKeys: String, CodingKey {
        case startMs = "start_ms"
        case text
    }
}

enum LyricsFetchResult {
    case loaded(LyricsPayload)
    case empty
    case failed
}

struct LyricsTranslationPayload: Codable, Equatable {
    let translations: [String]
    let romanizations: [String]
}

private struct LyricsTranslationDecodedPayload: Codable, Equatable {
    let translations: [String]
    let romanizations: [String?]
}

enum LyricsTranslationResult {
    case loaded(LyricsTranslationPayload)
    case failed
}

final class LyricsCache {
    static let shared = LyricsCache()
    private init() {}

    private static let directoryName = "LyricsCache"
    private let memoryQueue = DispatchQueue(label: "LyricsCache.memory.queue", attributes: .concurrent)
    private var memoryCache: [String: LyricsPayload] = [:]
    private var memoryTranslationCache: [String: LyricsTranslationPayload] = [:]

    static func cacheDirectoryPath() -> String? {
        shared.directoryURL?.path
    }

    static func videoId(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }

        let host = url.host?.lowercased() ?? ""

        // https://youtu.be/e0Y39QnwRvY
        if host.contains("youtu.be") {
            return url.pathComponents.dropFirst().first
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let videoId = queryItems.first(where: { $0.name == "v" })?.value {
            return videoId
        }

        // https://www.youtube.com/watch?v=e0Y39QnwRvY
        if host.contains("youtube.com"),
           let shortsIndex = url.pathComponents.firstIndex(of: "shorts"),
           url.pathComponents.count > shortsIndex + 1 {
            return url.pathComponents[shortsIndex + 1]
        }

        return nil
    }

    static func activeLyricIndex(for payload: LyricsPayload, currentTimeMs: Int) -> Int? {
        guard payload.timed, !payload.lines.isEmpty else { return nil }

        var activeIndex: Int?
        for (index, line) in payload.lines.enumerated() {
            guard let startMs = line.startMs else { continue }
            if startMs <= currentTimeMs {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }

    func fetchLyrics(
        originalUrl: String,
        title: String,
        artists: [String],
        completion: @escaping (LyricsFetchResult) -> Void
    ) {
        guard let videoId = Self.videoId(from: originalUrl) else {
            completion(.empty)
            return
        }
        fetchLyrics(videoId: videoId, title: title, artists: artists, completion: completion)
    }

    func fetchLyrics(
        videoId: String,
        title: String,
        artists: [String],
        completion: @escaping (LyricsFetchResult) -> Void
    ) {
        if let cached = getFromMemory(videoId: videoId) {
            completion(.loaded(cached))
            return
        }

        if let data = loadFromDisk(videoId: videoId) {
            if let payload = try? JSONDecoder().decode(LyricsPayload.self, from: data) {
                setInMemory(payload, videoId: videoId)
                completion(.loaded(payload))
                return
            } else {
                removeFromDisk(videoId: videoId)
            }
        }

        let primaryArtist = artists.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let queryParts = [
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryArtist
        ]
            .filter { !$0.isEmpty }
        let geniusQuery = queryParts.joined(separator: " ")

        func fetchFromGenius() {
            guard !primaryArtist.isEmpty, !geniusQuery.isEmpty else {
                debugPrint("LyricsCache: skipping Genius lookup (missing artist/query) for \(videoId)")
                completion(.empty)
                return
            }

            debugPrint("LyricsCache: fetching Genius lyrics for \(videoId) with query '\(geniusQuery)'")
            let escapedQuery = escapeForPythonString(geniusQuery)
            let geniusCode = """
from arbor import get_lyrics_from_genius
result = get_lyrics_from_genius('\(escapedQuery)')
"""

            pythonExecAndGetStringAsync(
                geniusCode.trimmingCharacters(in: .whitespacesAndNewlines),
                "result"
            ) { result in
                guard let output = result, !output.isEmpty else {
                    debugPrint("LyricsCache: Genius returned empty result for \(videoId)")
                    completion(.empty)
                    return
                }

                guard let data = output.data(using: .utf8),
                      let payload = try? JSONDecoder().decode(LyricsPayload.self, from: data) else {
                    debugPrint("LyricsCache: failed to decode Genius lyrics for \(videoId)")
                    completion(.failed)
                    return
                }

                guard !payload.lines.isEmpty else {
                    debugPrint("LyricsCache: Genius returned no lyric lines for \(videoId)")
                    completion(.empty)
                    return
                }

                self.setInMemory(payload, videoId: videoId)
                self.saveToDisk(data: data, videoId: videoId)
                completion(.loaded(payload))
            }
        }

        let escaped = escapeForPythonString(videoId)
        let code = """
from arbor.lyrics import get_lyrics_from_youtube
result = get_lyrics_from_youtube('\(escaped)')
"""

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
        ) { result in
            guard let output = result, !output.isEmpty else {
                debugPrint("LyricsCache: YouTube returned empty result for \(videoId); falling back to Genius")
                fetchFromGenius()
                return
            }

            guard let data = output.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(LyricsPayload.self, from: data) else {
                debugPrint("LyricsCache: failed to decode YouTube lyrics for \(videoId); falling back to Genius")
                fetchFromGenius()
                return
            }

            guard !payload.lines.isEmpty else {
                debugPrint("LyricsCache: YouTube returned no lyric lines for \(videoId); falling back to Genius")
                fetchFromGenius()
                return
            }

            self.setInMemory(payload, videoId: videoId)
            self.saveToDisk(data: data, videoId: videoId)
            completion(.loaded(payload))
        }
    }

    func translateLyrics(
        originalUrl: String,
        payload: LyricsPayload,
        completion: @escaping (LyricsTranslationResult) -> Void
    ) {
        guard let videoId = Self.videoId(from: originalUrl) else {
            completion(.failed)
            return
        }
        translateLyrics(videoId: videoId, payload: payload, completion: completion)
    }

    func translateLyrics(
        videoId: String,
        payload: LyricsPayload,
        completion: @escaping (LyricsTranslationResult) -> Void
    ) {
        if let cached = getTranslationFromMemory(videoId: videoId) {
            completion(.loaded(cached))
            return
        }

        if let data = loadTranslationFromDisk(videoId: videoId) {
            if let payload = try? JSONDecoder().decode(LyricsTranslationPayload.self, from: data) {
                setTranslationInMemory(payload, videoId: videoId)
                completion(.loaded(payload))
                return
            } else {
                removeTranslationFromDisk(videoId: videoId)
            }
        }

        let texts = payload.lines.map { $0.text }
        guard let data = try? JSONSerialization.data(withJSONObject: texts, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            completion(.failed)
            return
        }

        let escaped = escapeForPythonString(jsonString)
        let code = """
import json
from arbor.translate import translate
payload = json.loads('\(escaped)')
result = translate(payload)
"""

        pythonExecAndGetStringAsync(
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "result"
        ) { result in
            guard let output = result,
                  let data = output.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode(LyricsTranslationDecodedPayload.self, from: data),
                  parsed.romanizations.count == texts.count,
                  parsed.translations.count == texts.count else {
                completion(.failed)
                return
            }

            let romanizedLines = parsed.romanizations.enumerated().map { index, value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? texts[index] : trimmed
            }
            let sanitizedPayload = LyricsTranslationPayload(
                translations: parsed.translations,
                romanizations: romanizedLines
            )
            if let encoded = try? JSONEncoder().encode(sanitizedPayload) {
                self.saveTranslationToDisk(data: encoded, videoId: videoId)
            }
            self.setTranslationInMemory(sanitizedPayload, videoId: videoId)
            completion(.loaded(sanitizedPayload))
        }
    }

    func clearAll() {
        clearMemory()
        clearDisk()
    }

    private func getFromMemory(videoId: String) -> LyricsPayload? {
        var result: LyricsPayload?
        memoryQueue.sync {
            result = memoryCache[videoId]
        }
        return result
    }

    private func setInMemory(_ payload: LyricsPayload, videoId: String) {
        memoryQueue.sync(flags: .barrier) {
            memoryCache[videoId] = payload
        }
    }

    private func getTranslationFromMemory(videoId: String) -> LyricsTranslationPayload? {
        var result: LyricsTranslationPayload?
        memoryQueue.sync {
            result = memoryTranslationCache[videoId]
        }
        return result
    }

    private func setTranslationInMemory(_ payload: LyricsTranslationPayload, videoId: String) {
        memoryQueue.sync(flags: .barrier) {
            memoryTranslationCache[videoId] = payload
        }
    }

    private func clearMemory() {
        memoryQueue.sync(flags: .barrier) {
            memoryCache.removeAll()
            memoryTranslationCache.removeAll()
        }
    }

    private var directoryURL: URL? {
        let tmpPath = NSTemporaryDirectory()
        guard !tmpPath.isEmpty else { return nil }
        return URL(fileURLWithPath: tmpPath, isDirectory: true)
            .appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    private func loadFromDisk(videoId: String) -> Data? {
        guard let url = fileURL(for: videoId) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func saveToDisk(data: Data, videoId: String) {
        guard let url = fileURL(for: videoId) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func removeFromDisk(videoId: String) {
        guard let url = fileURL(for: videoId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func loadTranslationFromDisk(videoId: String) -> Data? {
        guard let url = translationFileURL(for: videoId) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func saveTranslationToDisk(data: Data, videoId: String) {
        guard let url = translationFileURL(for: videoId) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func removeTranslationFromDisk(videoId: String) {
        guard let url = translationFileURL(for: videoId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func clearDisk() {
        guard let dirURL = directoryURL else { return }
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }
        let contents = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: nil
        )
        contents?.forEach { item in
            try? FileManager.default.removeItem(at: item)
        }
    }

    private func fileURL(for videoId: String) -> URL? {
        guard let dirURL = ensureDirectory() else { return nil }
        let filename = sanitizedFileName(videoId)
        return dirURL.appendingPathComponent(filename).appendingPathExtension("json")
    }

    private func translationFileURL(for videoId: String) -> URL? {
        guard let dirURL = ensureDirectory() else { return nil }
        let filename = sanitizedFileName(videoId) + ".translations"
        return dirURL.appendingPathComponent(filename).appendingPathExtension("json")
    }

    private func ensureDirectory() -> URL? {
        guard let dirURL = directoryURL else { return nil }
        if !FileManager.default.fileExists(atPath: dirURL.path) {
            try? FileManager.default.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true
            )
        }
        return dirURL
    }

    private func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
        )
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                result.append("_")
            }
        }
        return result.isEmpty ? "lyrics" : result
    }

    private func escapeForPythonString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
