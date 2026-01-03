import Foundation
import ScrobbleKit

// exists so we can persist to disk
struct CachedScrobble: Codable, Equatable {
    let artist: String
    let track: String
    let timestamp: Date
    let album: String?
    let albumArtist: String?
    let trackNumber: Int?
    let duration: Int?
    let chosenByUser: Bool?
    let mbid: String?

    func toTrack() -> SBKTrackToScrobble {
        SBKTrackToScrobble(
            artist: artist,
            track: track,
            timestamp: timestamp,
            album: album,
            albumArtist: albumArtist,
            trackNumber: trackNumber,
            duration: duration,
            chosenByUser: chosenByUser,
            mbid: mbid
        )
    }
}

actor ScrobbleQueue {
    private var pending: [CachedScrobble]
    private let fileURL: URL
    private var isFlushing = false

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = baseDirectory?.appendingPathComponent("Arbor", isDirectory: true)
        fileURL = directory?.appendingPathComponent("ScrobbleQueue.json") ?? URL(fileURLWithPath: "ScrobbleQueue.json")
        pending = []
        loadFromDisk()
    }

    func enqueue(_ scrobble: CachedScrobble) async {
        pending.append(scrobble)
        saveToDisk()
    }

    func flushIfNeeded(manager: SBKManager?) async {
        guard let manager, !pending.isEmpty, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        await flush(manager: manager)
    }

    private func flush(manager: SBKManager) async {
        while !pending.isEmpty {
            let batch = Array(pending.prefix(50))
            let tracks = batch.map { $0.toTrack() }

            do {
                let response = try await manager.scrobble(tracks: tracks)
                guard response.results.count == batch.count else { break }

                var retained: [CachedScrobble] = []
                for (index, result) in response.results.enumerated() {
                    if !result.isAccepted {
                        if let error = result.error, isRetriable(error: error) {
                            retained.append(batch[index])
                        }
                    }
                }

                let remaining = Array(pending.dropFirst(batch.count))
                pending = retained + remaining
                saveToDisk()

                if !retained.isEmpty {
                    break
                }
            } catch {
                break
            }
        }
    }

    private func isRetriable(error: SBKScrobbleError) -> Bool {
        switch error {
        case .dailyScrobbleLimitExceeded, .timestampTooNew, .unknown:
            return true
        case .artistIgnored, .trackIgnored, .timestampTooOld:
            return false
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([CachedScrobble].self, from: data) else {
            pending = []
            return
        }
        pending = decoded
    }

    private func saveToDisk() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        guard let data = try? encoder.encode(pending) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
