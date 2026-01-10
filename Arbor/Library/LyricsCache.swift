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

struct LyricsTranslationPayload: Equatable {
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

    func fetchLyrics(originalUrl: String, completion: @escaping (LyricsFetchResult) -> Void) {
        guard let videoId = Self.videoId(from: originalUrl) else {
            completion(.empty)
            return
        }
        fetchLyrics(videoId: videoId, completion: completion)
    }

    func fetchLyrics(videoId: String, completion: @escaping (LyricsFetchResult) -> Void) {
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
                completion(.empty)
                return
            }

            guard let data = output.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(LyricsPayload.self, from: data) else {
                completion(.failed)
                return
            }

            self.setInMemory(payload, videoId: videoId)
            self.saveToDisk(data: data, videoId: videoId)
            completion(.loaded(payload))
        }
    }

    func translateLyrics(payload: LyricsPayload, completion: @escaping (LyricsTranslationResult) -> Void) {
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

    private func clearMemory() {
        memoryQueue.sync(flags: .barrier) {
            memoryCache.removeAll()
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
