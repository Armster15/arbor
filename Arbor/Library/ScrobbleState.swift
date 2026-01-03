import Foundation

// ScrobbleSeed exists so the actor only receives
// Sendable, immutable data. LibraryItem is a SwiftData
// @Model reference type, not Sendable, and shouldn't
// cross actor boundaries.
struct ScrobbleSeed: Sendable {
    let title: String
    let artist: String?
    let album: String?
}

// Tracks listening progress and decides when a track meets Last.fm scrobble criteria.
final class ScrobbleState {
    private let title: String
    private let artist: String
    private let album: String?
    private let startedAt: Date

    private var duration: Double = 0
    private var thresholdSeconds: Double?
    private var listenedSeconds: Double = 0
    private var lastObservedTime: Double?
    private var scrobbled = false

    init?(seed: ScrobbleSeed) {
        // Since scrobbleState in PlayerCoordinator is already optional, songs without
        // any artists will simply have scrobbleState = nil and won't be scrobbled.
        guard let artist = seed.artist else { return nil }

        self.title = seed.title
        self.artist = artist
        self.album = seed.album
        self.startedAt = Date()
    }

    func updateDuration(_ duration: Double) {
        self.duration = duration
        // Only scrobble tracks longer than 30 seconds.
        guard duration > 30 else {
            thresholdSeconds = nil
            return
        }
        // Scrobble after half the duration or 4 minutes, whichever comes first.
        thresholdSeconds = min(duration / 2.0, 240.0)
    }

    func shouldScrobble(currentTime: Double, isPlaying: Bool) -> Bool {
        if !isPlaying {
            lastObservedTime = currentTime
            return false
        }

        guard let lastObservedTime else {
            self.lastObservedTime = currentTime
            return false
        }

        let delta = currentTime - lastObservedTime
        self.lastObservedTime = currentTime

        guard delta >= 0, delta <= 5 else { return false }
        listenedSeconds += delta

        guard let thresholdSeconds, !scrobbled else { return false }
        return listenedSeconds >= thresholdSeconds
    }

    func markScrobbled() {
        scrobbled = true
    }

    func toCachedScrobble() -> CachedScrobble {
        CachedScrobble(
            artist: artist,
            track: title,
            timestamp: startedAt,
            album: album,
            albumArtist: nil,
            trackNumber: nil,
            duration: duration > 0 ? Int(duration.rounded()) : nil,
            chosenByUser: true,
            mbid: nil
        )
    }
}
