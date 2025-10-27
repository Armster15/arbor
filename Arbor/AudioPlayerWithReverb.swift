//
//  AudioPlayerWithReverb.swift
//  arbor
//

import AVFoundation
import SwiftAudioPlayer
import MediaPlayer
import UIKit
import SDWebImage

final class AudioPlayerWithReverb: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLooping: Bool = false
    
    @Published var speedRate: Float = 1.0
    @Published var pitchCents: Float = 0.0
    @Published var reverbMix: Float = 0.0

    private var elapsedSub: UInt?
    private var durationSub: UInt?
    private var statusSub: UInt?

    private var remoteCommandsConfigured: Bool = false
    
    // now playing metadata
    private var metaTitle: String?
    private var metaArtist: String?
    private var metaArtwork: MPMediaItemArtwork?
    
    private var pitchNode: AVAudioUnitTimePitch
    private var reverbNode: AVAudioUnitReverb
    
    private var volumeRampTimer: Timer? // track volume ramp timer to prevent race conditions
    
    init() {
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()
                
        // Default parameters
        reverbNode.wetDryMix = reverbMix
        pitchNode.rate = speedRate
        
        // Connect nodes: player -> pitch -> reverb -> output
        SAPlayer.shared.audioModifiers = [pitchNode, reverbNode]
    }

    func startSavedAudio(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        SAPlayer.shared.startSavedAudio(withSavedUrl: url, mediaInfo: nil)
        configureRemoteCommandsIfNeeded()
        subscribeUpdates()
        updateNowPlayingInfo()
    }

    func play(shouldRampVolume: Bool = true) {
        // Fade in over 300ms with exponential curve, but *not* when starting from the beginning
        let justStarted = currentTime <= 0.05
        if shouldRampVolume == true && !justStarted {
            rampVolume(from: 0.0, to: 1.0, duration: 0.3)
        } else {
            // required to override any race conditions where we may already be ramping the volume at some point
            SAPlayer.shared.volume = 1.0
        }
        
        SAPlayer.shared.play()
    }

    func pause() {        
        rampVolume(from: SAPlayer.shared.volume ?? 0.0, to: 0.0, duration: 0.3) {
            SAPlayer.shared.pause()
        }
    }

    func seek(to seconds: Double) {
        SAPlayer.shared.seekTo(seconds: seconds)
    }

    func stop() {
        self.pause()
        self.seek(to: 0)
        isPlaying = false
        currentTime = 0
    }

    func toggleLoop() {
        let new = !self.isLooping
        
        if new {
            SAPlayer.Features.Loop.enable()
        }
        else {
            SAPlayer.Features.Loop.disable()
        }
        
        self.isLooping = new
    }

    // Adjust pitch in cents (-2400...+2400). 100 cents = 1 semitone.
    func setPitchByCents(_ cents: Float) {
        let clamped = min(max(cents, -2400), 2400)
        if pitchNode.pitch != clamped {
            pitchNode.pitch = clamped
        }
        if pitchCents != pitchNode.pitch {
            pitchCents = pitchNode.pitch
        }
    }
    
    // Adjust playback speed (0.25x ... 2.0x)
    func setSpeedRate(_ newRate: Float) {
        let clamped = min(max(newRate, 0.25), 2.0)
        if pitchNode.rate != clamped {
            pitchNode.rate = clamped
        }
        if speedRate != pitchNode.rate {
            speedRate = pitchNode.rate
        }
        
        // Update Now Playing info with new playback rate
        if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? speedRate : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
        
    // Adjust reverb intensity (0-100)
    func setReverbMix(_ mix: Float) {
        let clamped = min(max(mix, 0), 100)
        if reverbNode.wetDryMix != clamped {
            reverbNode.wetDryMix = clamped
        }
        if reverbMix != reverbNode.wetDryMix {
            reverbMix = reverbNode.wetDryMix
        }
    }


    private func subscribeUpdates() {
        if elapsedSub == nil {
            elapsedSub = SAPlayer.Updates.ElapsedTime.subscribe { [weak self] time in
                self?.currentTime = time
                var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
        if durationSub == nil {
            durationSub = SAPlayer.Updates.Duration.subscribe { [weak self] dur in
                self?.duration = dur
                var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = dur
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
        if statusSub == nil {
            statusSub = SAPlayer.Updates.PlayingStatus.subscribe { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.speedRate
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                case .ended:
                    if self.isLooping {
                        self.seek(to: 0)
                        self.play()
                        self.isPlaying = true
                        self.currentTime = 0
                        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
                        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.speedRate
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    } else {
                        self.isPlaying = false
                        self.pause()
                        self.seek(to: 0)
                        self.currentTime = 0
                        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
                        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                default:
                    self.isPlaying = false
                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
        
        // SAPlayer automatically adds commands, so we need to clear them to manually implement this
        SAPlayer.shared.clearLockScreenInfo()
        updateNowPlayingInfo()

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = true
        commandCenter.seekForwardCommand.isEnabled = true

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
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: event.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let title = metaTitle {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        
        if let artist = metaArtist, !artist.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }
        
        if let artwork = metaArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        
        // Set playback rate + this also indicates if we're paused or playing
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? speedRate : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func rampVolume(from startVolume: Float, to endVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        // Cancel any existing ramp timer to prevent race conditions
        volumeRampTimer?.invalidate()
        
        let steps = 60 // More steps for smoother transition
        let stepDuration = duration / Double(steps)
        
        var currentStep = 0
        let timer = Timer(timeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            // Use exponential curve for more natural-sounding fade
            let curvedProgress: Float
            if endVolume > startVolume {
                // Fade in: exponential curve
                curvedProgress = progress * progress
            } else {
                // Fade out: inverse exponential curve
                curvedProgress = 1.0 - (1.0 - progress) * (1.0 - progress)
            }
            
            let newVolume = startVolume + (endVolume - startVolume) * curvedProgress
            SAPlayer.shared.volume = newVolume
            
            if currentStep >= steps {
                timer.invalidate()
                self.volumeRampTimer = nil
                SAPlayer.shared.volume = endVolume
                completion?()
            }
        }
        timer.tolerance = stepDuration * 0.2
        RunLoop.main.add(timer, forMode: .common)
        volumeRampTimer = timer
    }

    
    func updateMetadataTitle(_ title: String? = nil) {
        self.metaTitle = title
        updateNowPlayingInfo()
    }
    
    func updateMetadataArtist(_ artist: String? = nil) {
        self.metaArtist = artist
        updateNowPlayingInfo()
    }

    func updateMetadataArtwork(url: URL) {
        SDWebImageManager.shared.loadImage(with: url, options: [.highPriority, .retryFailed, .scaleDownLargeImages], progress: nil) { image, _, error, _, finished, _ in
            guard error == nil, finished, let image else {
                print("Failed to load artwork via SDWebImage: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.metaArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            
            self.updateNowPlayingInfo()
        }
    }

}
