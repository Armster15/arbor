//
//  PlayerView.swift
//  pytest
//

import AVFoundation
import AudioStreaming
import MediaPlayer
import SwiftUI

@MainActor
class AudioPlayerWithReverb: ObservableObject {
    private var player: AudioPlayer

    private var pitchNode: AVAudioUnitTimePitch
    private var reverbNode: AVAudioUnitReverb

    @Published public var isPlaying: Bool = false
    @Published public var speedRate: Float = 1.0
    @Published public var reverbMix: Float = 0.0
    @Published public var pitchCents: Float = 0.0
    @Published public var isLooping: Bool = false

    @Published public var currentTime: TimeInterval = 0.0
    @Published public var duration: TimeInterval = 0.0
    private var displayLink: CADisplayLink?  // timer that synchronizes with the screen's refresh rate
    private var seekOffset: AVAudioFramePosition = 0  // Track where we seeked to
    private var isSeeking: Bool = false

    private var remoteCommandsConfigured: Bool = false
    private var hasPlayedBefore: Bool = false

    // Loaded args
    private var url: URL?
    private var metaTitle: String?
    private var metaArtist: String?
    private var metaArtworkURL: URL?

    init() {
        player = AudioPlayer()
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()

        setupAudioEngine()
        setupAudioSession()
        setupRemoteCommands()

        // Default parameters
        pitchNode.rate = speedRate
    }

    private func setupAudioEngine() {
        player.attach(node: pitchNode)
        player.attach(node: reverbNode)
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func setupRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.play()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.pause()
            return .success
        }

        // Stop command
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.stop()
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
            } else {
                self.play()
            }
            return .success
        }

        // Previous track command (restart from beginning with fast rewind icon)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.seek(to: 0)
            return .success
        }

        // Next track command (restart from beginning with fast forward icon)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.seek(to: 0)
            return .success
        }

        // Change playback position command (scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }
            self.seek(to: event.positionTime)
            return .success
        }
    }

    func loadAudio(
        url: URL, metaTitle: String? = nil, metaArtist: String? = nil, metaArtworkURL: URL? = nil
    ) throws {
        self.url = url
        self.metaTitle = metaTitle
        self.metaArtist = metaArtist
        self.metaArtworkURL = metaArtworkURL

        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let title = metaTitle {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }

        if let artist = metaArtist, !artist.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }

        if let artworkURL = metaArtworkURL {
            Task {
                await loadAndSetArtwork(from: artworkURL)
            }
        }

        // Set duration
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration

        // Set current playback time
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime

        // Set playback rate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? speedRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func loadAndSetArtwork(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    return image
                }

                // Update Now Playing info with artwork
                var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        } catch {
            print("Failed to load artwork: \(error)")
        }
    }

    func play() {
        if hasPlayedBefore {
            player.resume()
        } else {
            guard let url = self.url else { return }
            player.play(url: url)
            hasPlayedBefore = true
        }
        
        self.isPlaying = true

        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        
        self.isPlaying = false

        updateNowPlayingInfo()
    }

    func toggleLoop() {
        isLooping = !isLooping
    }

    func stop() {
        player.stop()
        updateNowPlayingInfo()
        self.isPlaying = false
        self.hasPlayedBefore = false
    }

    func seek(to time: Double) {
        player.seek(to: time)
        updateNowPlayingInfo()
    }

    func teardown() {
        player.detachCustomAttachedNodes()
        player.stop()
    }

    func updateTitle(title: String) {
        metaTitle = title
        updateNowPlayingInfo()
    }

    // Adjust pitch in cents (-2400...+2400). 100 cents = 1 semitone.
    func setPitchByCents(_ cents: Float) {
        pitchNode.pitch = min(max(cents, -2400), 2400)
        pitchCents = pitchNode.pitch
    }

    // Adjust playback speed (0.25x ... 2.0x)
    func setSpeedRate(_ newRate: Float) {
        pitchNode.rate = min(max(newRate, 0.25), 2.0)
        speedRate = pitchNode.rate

        // Update Now Playing info with new playback rate
        if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? speedRate : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    // Adjust reverb intensity (0-100)
    func setReverbMix(_ mix: Float) {
        reverbNode.wetDryMix = min(max(mix, 0), 100)
        reverbMix = reverbNode.wetDryMix
    }

    @MainActor deinit {
        teardown()
    }
}

struct PlayerScreen: View {
    let meta: DownloadMeta
    @ObservedObject var audioPlayer: AudioPlayerWithReverb

    private func decoratedTitle() -> String {
        var tags: [String] = []
        if audioPlayer.speedRate > 1.0 {
            tags.append("sped up")
        } else if audioPlayer.speedRate < 1.0 {
            tags.append("slowed")
        }
        if audioPlayer.reverbMix > 0.0 {
            if tags.isEmpty {
                tags.append("reverb")
            } else {
                tags.append("reverb")
            }
        }
        guard !tags.isEmpty else { return meta.title }
        return "\(meta.title) (\(tags.joined(separator: " + ")))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    // Metadata header
                    VStack(spacing: 16) {
                        if let thumbnailUrl = meta.thumbnail_url,
                            let isSquare = meta.thumbnail_is_square
                        {
                            if isSquare == true {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 180, height: 180)
                                            .clipped()
                                            .cornerRadius(12)
                                            .shadow(
                                                color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: 180, height: 180)
                                    }
                                }
                            } else {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 180)
                                            .clipped()
                                            .cornerRadius(12)
                                            .shadow(
                                                color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                                    } placeholder: {
                                        ProgressView()
                                            .frame(height: 180)
                                    }
                                }
                            }
                        }

                        VStack(spacing: 4) {
                            Text(meta.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)

                            if let artist = meta.artist, !artist.isEmpty {
                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 24) {
                        // Rewind
                        Button(action: {
                            audioPlayer.seek(to: 0)

                        }) {
                            Image(systemName: "backward.end.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)
                        }

                        // Play / Pause
                        Button(action: {
                            if audioPlayer.isPlaying {
                                audioPlayer.pause()
                            } else {
                                audioPlayer.play()
                            }
                        }) {
                            Image(
                                systemName: audioPlayer.isPlaying
                                    ? "pause.circle.fill" : "play.circle.fill"
                            )
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                        }

                        // Stop
                        Button(action: {
                            audioPlayer.stop()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.red)
                        }

                        // Loop
                        Button(action: {
                            audioPlayer.toggleLoop()
                        }) {
                            Image(
                                systemName: audioPlayer.isLooping
                                    ? "repeat.circle.fill" : "repeat.circle"
                            )
                            .font(.system(size: 44))
                            .foregroundColor(
                                audioPlayer.isLooping ? .green : .secondary
                            )
                            .accessibilityLabel(
                                audioPlayer.isLooping ? "Disable Loop" : "Enable Loop"
                            )
                        }
                    }

                    // Scrubber
                    VStack {
                        HStack {
                            Text(formattedTime(audioPlayer.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(formattedTime(audioPlayer.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration)
                    }
                }

                // Slider sections
                VStack(alignment: .leading, spacing: 24) {
                    // Speed
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Button("Reset") {
                                audioPlayer.setSpeedRate(1.0)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .opacity(audioPlayer.speedRate == 1.0 ? 0 : 1)

                            Spacer()

                            Text(String(format: "%.2fx", audioPlayer.speedRate))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.speedRate)
                                    },
                                    set: { newVal in
                                        // Slider sends continuous values while dragging, so we snap to the nearest 0.05 to enforce stepping.
                                        let snapped = (newVal / 0.05).rounded() * 0.05
                                        audioPlayer.setSpeedRate(Float(snapped))
                                    }
                                ),
                                in: 0.25...2.0,
                                step: 0.05
                            )
                            // `flex: 1` (???)
                            .frame(maxWidth: .infinity)

                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.speedRate)
                                    },
                                    set: { newVal in
                                        audioPlayer.setSpeedRate(Float(newVal))
                                    }
                                ),
                                in: 0.25...2.0,
                                step: 0.01,
                            ) {}
                            .fixedSize()
                        }
                    }

                    // Pitch (cents)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Button("Reset") {
                                audioPlayer.setPitchByCents(0.0)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .opacity(audioPlayer.pitchCents.isZero ? 0 : 1)

                            Spacer()

                            Text("\(Int(audioPlayer.pitchCents)) cents")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.pitchCents)
                                    },
                                    set: { newVal in
                                        // Slider sends continuous values while dragging, so we snap to the nearest 50 to enforce stepping.
                                        let snapped = (newVal / 50.0).rounded() * 50.0
                                        audioPlayer.setPitchByCents(Float(snapped))
                                    }
                                ),
                                in: -800...800,
                                step: 50
                            )
                            .frame(maxWidth: .infinity)

                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.pitchCents)
                                    },
                                    set: { newVal in
                                        audioPlayer.setPitchByCents(Float(newVal))
                                    }
                                ),
                                in: -800...800,
                                step: 10,
                            ) {}
                            .fixedSize()
                        }
                    }

                    // Reverb
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reverb")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Button("Reset") {
                                audioPlayer.setReverbMix(0.0)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .opacity(audioPlayer.reverbMix > 0 ? 1 : 0)

                            Spacer()

                            Text(String(format: "%.0f%%", audioPlayer.reverbMix))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.reverbMix)
                                    },
                                    set: { newVal in
                                        audioPlayer.setReverbMix(Float(newVal))
                                    }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .frame(maxWidth: .infinity)

                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(audioPlayer.reverbMix)
                                    },
                                    set: { newVal in
                                        audioPlayer.setReverbMix(Float(newVal))
                                    }
                                ),
                                in: 0...100,
                                step: 1,
                            ) {}
                            .fixedSize()
                        }
                    }
                }
            }
            .padding()
        }
        .onChange(of: audioPlayer.speedRate) { _, _ in
            audioPlayer.updateTitle(title: decoratedTitle())
        }
        .onChange(of: audioPlayer.reverbMix) { _, _ in
            audioPlayer.updateTitle(title: decoratedTitle())
        }
    }
}

private func formattedTime(_ seconds: Double) -> String {
    guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
    let s = Int(seconds.rounded())
    let mins = s / 60
    let secs = s % 60
    return String(format: "%d:%02d", mins, secs)
}
