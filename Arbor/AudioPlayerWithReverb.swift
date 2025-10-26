//
//  PlayerView.swift
//  pytest
//

import AVFoundation
import SwiftAudioPlayer
import MediaPlayer
import UIKit
import Combine

final class AudioPlayerWithReverb: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0
    @Published var pitch: Float = 0.0
    @Published var isLooping: Bool = false
    @Published var reverbWetDryMix: Float = 0.0
    @Published var reverbPresetRaw: Int = AVAudioUnitReverbPreset.mediumHall.rawValue
    @Published var displayTitle: String = "Audio"
    @Published var displayArtist: String? = nil
    @Published var displayArtwork: UIImage? = nil
    @Published var isArtworkSquare: Bool? = nil

    private var elapsedSub: UInt?
    private var durationSub: UInt?
    private var statusSub: UInt?

    private var remoteCommandsConfigured: Bool = false
    private var nowPlayingTitle: String = "Audio"
    private var nowPlayingArtist: String? = nil
    private var nowPlayingArtwork: MPMediaItemArtwork? = nil
    private var nowPlayingArtworkImage: UIImage? = nil
    
    private func setupAudioPlayer(filePath: String) {
        // Initialize SAPlayer with saved file and attach TimePitch for speed/pitch and Reverb effect
        let timePitch = AVAudioUnitTimePitch()
        let reverb = AVAudioUnitReverb()
        reverb.wetDryMix = 0
        SAPlayer.shared.audioModifiers = [timePitch, reverb]
        self.setRate(1.0)
        self.setPitch(0.0)
        self.setReverbWetDryMix(0.0)
        self.startSavedAudio(filePath: filePath)
    }

    func startSavedAudio(filePath: String) {
        // Ensure audio modifiers (time pitch and reverb) are configured before starting playback
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = rate
        timePitch.pitch = pitch
        let reverb = AVAudioUnitReverb()
        if let preset = AVAudioUnitReverbPreset(rawValue: reverbPresetRaw) {
            reverb.loadFactoryPreset(preset)
        }
        reverb.wetDryMix = reverbWetDryMix
        SAPlayer.shared.audioModifiers = [timePitch, reverb]

        let url = URL(fileURLWithPath: filePath)
        SAPlayer.shared.startSavedAudio(withSavedUrl: url, mediaInfo: nil)
        nowPlayingTitle = url.deletingPathExtension().lastPathComponent
        displayTitle = nowPlayingTitle
        displayArtist = nowPlayingArtist
        displayArtwork = nil
        configureRemoteCommandsIfNeeded()
        subscribeUpdates()
        updateNowPlayingInfo()
    }

    func setMetadata(title: String?, artist: String?, artworkURL: URL?) {
        if let t = title, !t.isEmpty {
            nowPlayingTitle = t
        }
        nowPlayingArtist = artist
        if let url = artworkURL {
            fetchArtwork(from: url)
        } else {
            nowPlayingArtwork = nil
            nowPlayingArtworkImage = nil
            isArtworkSquare = nil
            updateNowPlayingInfo()
        }
    }

    func play() {
        SAPlayer.shared.play()
    }

    func pause() {
        SAPlayer.shared.pause()
    }

    func toggle() {
        SAPlayer.shared.togglePlayAndPause()
    }

    func seek(to seconds: Double) {
        SAPlayer.shared.seekTo(seconds: seconds)
    }

    func stop() {
        SAPlayer.shared.pause()
        SAPlayer.shared.seekTo(seconds: 0)
        isPlaying = false
        currentTime = 0
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if let node = SAPlayer.shared.audioModifiers.compactMap({ $0 as? AVAudioUnitTimePitch }).first {
            node.rate = newRate
            SAPlayer.shared.playbackRateOfAudioChanged(rate: newRate)
        }
        updateNowPlayingInfo()
    }

    func setPitch(_ newPitch: Float) {
        let rounded = Float(round(Double(newPitch)))
        pitch = rounded
        if let node = SAPlayer.shared.audioModifiers.compactMap({ $0 as? AVAudioUnitTimePitch }).first {
            node.pitch = rounded
        }
    }

    func setReverbWetDryMix(_ newMix: Float) {
        let clamped = max(0.0, min(100.0, newMix))
        reverbWetDryMix = clamped
        if let reverb = SAPlayer.shared.audioModifiers.compactMap({ $0 as? AVAudioUnitReverb }).first {
            reverb.wetDryMix = clamped
        }
        updateNowPlayingInfo()
    }

    func setReverbPresetRaw(_ raw: Int) {
        reverbPresetRaw = raw
        if let preset = AVAudioUnitReverbPreset(rawValue: raw),
           let reverb = SAPlayer.shared.audioModifiers.compactMap({ $0 as? AVAudioUnitReverb }).first {
            reverb.loadFactoryPreset(preset)
        }
    }

    private func subscribeUpdates() {
        if elapsedSub == nil {
            elapsedSub = SAPlayer.Updates.ElapsedTime.subscribe { [weak self] time in
                self?.currentTime = time
                self?.updateNowPlayingInfo()
            }
        }
        if durationSub == nil {
            durationSub = SAPlayer.Updates.Duration.subscribe { [weak self] dur in
                self?.duration = dur
                self?.updateNowPlayingInfo()
            }
        }
        if statusSub == nil {
            statusSub = SAPlayer.Updates.PlayingStatus.subscribe { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    self.updateNowPlayingInfo()
                case .ended:
                    if self.isLooping {
                        SAPlayer.shared.seekTo(seconds: 0)
                        SAPlayer.shared.play()
                        self.isPlaying = true
                        self.currentTime = 0
                        self.updateNowPlayingInfo()
                    } else {
                        self.isPlaying = false
                        SAPlayer.shared.pause()
                        SAPlayer.shared.seekTo(seconds: 0)
                        self.currentTime = 0
                        self.updateNowPlayingInfo()
                    }
                default:
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    func unsubscribeUpdates() {
        if let id = elapsedSub { SAPlayer.Updates.ElapsedTime.unsubscribe(id) }
        if let id = durationSub { SAPlayer.Updates.Duration.unsubscribe(id) }
        if let id = statusSub { SAPlayer.Updates.PlayingStatus.unsubscribe(id) }
        elapsedSub = nil
        durationSub = nil
        statusSub = nil
    }

    private func configureRemoteCommandsIfNeeded() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = true
        commandCenter.seekForwardCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            SAPlayer.shared.play()
            self?.updateNowPlayingInfo()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            SAPlayer.shared.pause()
            self?.updateNowPlayingInfo()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            SAPlayer.shared.togglePlayAndPause()
            self?.updateNowPlayingInfo()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            SAPlayer.shared.seekTo(seconds: 0)
            self?.updateNowPlayingInfo()
            return .success
        }

        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
            commandCenter.changePlaybackPositionCommand.addTarget { event in
                guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                SAPlayer.shared.seekTo(seconds: event.positionTime)
                return .success
            }
        }


        commandCenter.seekBackwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            switch event.type {
            case .beginSeeking:
                SAPlayer.shared.seekTo(seconds: 0)
                if self.isPlaying { SAPlayer.shared.play() }
                self.updateNowPlayingInfo()
                return .success
            case .endSeeking:
                return .success
            @unknown default:
                return .commandFailed
            }
        }
        commandCenter.seekForwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            switch event.type {
            case .beginSeeking:
                let target = min(self.currentTime + 15, self.duration > 0 ? self.duration : self.currentTime + 15)
                SAPlayer.shared.seekTo(seconds: target)
                if self.isPlaying { SAPlayer.shared.play() }
                self.updateNowPlayingInfo()
                return .success
            case .endSeeking:
                return .success
            @unknown default:
                return .commandFailed
            }
        }
    }

    private func updateNowPlayingInfo() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = decoratedTitle()
        if let artist = nowPlayingArtist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let artwork = nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        if duration.isFinite && duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if #available(iOS 10.0, *) {
            info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
            info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = 1
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = 0
            info[MPNowPlayingInfoPropertyIsLiveStream] = false
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        let newTitle = nowPlayingTitle
        let newArtist = nowPlayingArtist
        let newArtwork = nowPlayingArtworkImage
        DispatchQueue.main.async {
            self.displayTitle = newTitle
            self.displayArtist = newArtist
            self.displayArtwork = newArtwork
        }
    }

    private func fetchArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    self.nowPlayingArtwork = nil
                    self.nowPlayingArtworkImage = nil
                    self.isArtworkSquare = nil
                    self.updateNowPlayingInfo()
                }
                return
            }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            let size = image.size
            let square = abs(size.width - size.height) <= 2
            DispatchQueue.main.async {
                self.nowPlayingArtwork = artwork
                self.nowPlayingArtworkImage = image
                self.isArtworkSquare = square
                print("[Swift] PlayerView artwork size: \(Int(size.width))x\(Int(size.height)) | square? \(square)")
                self.updateNowPlayingInfo()
            }
        }.resume()
    }

    private func decoratedTitle() -> String {
        var tags: [String] = []
        if rate > 1.0 {
            tags.append("sped up")
        } else if rate < 1.0 {
            tags.append("slowed down")
        }
        if reverbWetDryMix > 0.0 {
            if tags.isEmpty {
                tags.append("reverb")
            } else {
                tags.append("reverb")
            }
        }
        guard !tags.isEmpty else { return nowPlayingTitle }
        return "\(nowPlayingTitle) (\(tags.joined(separator: " + ")))"
    }
}
