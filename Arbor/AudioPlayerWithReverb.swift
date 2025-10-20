//
//  AudioPlayerWithReverb.swift
//  arbor
//
//  Created by Armaan Aggarwal on 10/19/25.
//
import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayerWithReverb: ObservableObject {
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
        
    private var pitchNode: AVAudioUnitTimePitch
    private var reverbNode: AVAudioUnitReverb
    
    // metadata related to the loaded audio file (including the actual audiofile)
    private var audioFile: AVAudioFile?

    // publicly exposed properties
    @Published public var isPlaying: Bool = false
    @Published public var speedRate: Float = 1.0
    @Published public var reverbMix: Float = 0.0
    @Published public var pitchCents: Float = 0.0
    @Published public var isLooping: Bool = false

    // properties just for showing the currentTime/duration
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var duration: TimeInterval = 0.0
    private var displayLink: CADisplayLink? // timer that synchronizes with the screen's refresh rate
    private var seekOffset: AVAudioFramePosition = 0 // to track which frame we seeked to
    private var volumeRampTimer: Timer? // track volume ramp timer to prevent race conditions
    
    // now playing metadata
    private var metaTitle: String?
    private var metaArtist: String?
    private var metaArtwork: MPMediaItemArtwork?


    init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()
        
        setupAudioEngine()
        setupAudioSession()
        setupRemoteCommands()
        
        // Default parameters
        reverbNode.wetDryMix = reverbMix
        pitchNode.rate = speedRate
    }
    
    private func setupAudioEngine() {
        engine.attach(playerNode)
        engine.attach(pitchNode)
        engine.attach(reverbNode)
                
        // Connect nodes: player -> pitch -> reverb -> output
        engine.connect(playerNode, to: pitchNode, format: nil)
        engine.connect(pitchNode, to: reverbNode, format: nil)
        engine.connect(reverbNode, to: engine.mainMixerNode, format: nil)
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Listen for audio session interruptions (e.g., when switching to another app)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )            
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
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
        
    func loadAudio(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        loadAudio(file: file)
    }
    
    func loadAudio(file: AVAudioFile) {
        let sampleRate = file.processingFormat.sampleRate
        let frameCount = file.length
        
        self.seekOffset = 0
        self.duration = Double(frameCount) / sampleRate
        self.audioFile = file
        
        playerNode.scheduleFile(file, at: nil)
        
        updateNowPlayingInfo()
    }
    
    func loadMetadataStrings(title: String? = nil, artist: String? = nil) {
        self.metaTitle = title
        self.metaArtist = artist
        
        updateNowPlayingInfo()
    }
    
    func loadMetadataArtwork(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                self.metaArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    return image
                }
            }
        } catch {
            print("Failed to load artwork: \(error)")
        }
    }
    
    func play(shouldRampVolume: Bool = true) {
        if !engine.isRunning {
            try? engine.start()
        }
        
        playerNode.play()
        isPlaying = true
        
        // Fade in over 300ms with exponential curve, but *not* when starting from the beginning
        let justStarted = currentTime <= 0.05 && seekOffset == 0
        if shouldRampVolume == true && !justStarted {
            rampVolume(from: 0.0, to: 1.0, duration: 0.3)
        } else {
            // required to override any race conditions where we may already be ramping the volume at some point
            engine.mainMixerNode.outputVolume = 1.0
        }
        
        updateNowPlayingInfo()
        startDisplayLink()
    }
    
    func pause() {
        isPlaying = false
        
        updateNowPlayingInfo()
        stopDisplayLink()
        
        rampVolume(from: engine.mainMixerNode.outputVolume, to: 0.0, duration: 0.3) { [weak self] in
            guard let self = self else { return }
            
            
            // VERY IMPORTANT: you MUST also use engine.pause() or otherwise the command center breaks and still marks
            // the audio as playing, and then you can't control the audio via the command center or your AirPods.
            // playerNode.pause() is required for syncing the correct currentTime
            playerNode.pause()
            self.engine.pause()
        }
    }

    func toggleLoop() {
        isLooping = !isLooping
    }
    
    func stop(queueAudio: Bool = true) {
        playerNode.stop()
        engine.stop()
        
        isPlaying = false
        currentTime = 0
        seekOffset = 0
        
        updateNowPlayingInfo()
        stopDisplayLink()
        
        if queueAudio == true {
            // schedule file so when `.play()` is called we have it queued up. we have to
            // put it here since we can't check if `playerNode` has a file scheduled or not
            if let file = self.audioFile {
                self.loadAudio(file: file)
            }
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        // Store if we were playing
        let wasPlaying = isPlaying
        
        // Stop current playback
        playerNode.stop()
        
        // Calculate frame position from time
        let sampleRate = audioFile.processingFormat.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)
        
        // Clamp the frame position to valid range
        let clampedFrame = min(max(framePosition, 0), audioFile.length)
        
        // Store the seek offset so updateCurrentTime can calculate correctly
        seekOffset = clampedFrame
        
        // Calculate the frames remaining from the seek position
        let frameCount = AVAudioFrameCount(audioFile.length - clampedFrame)
        
        // Update current time
        currentTime = Double(clampedFrame) / sampleRate
        
        // Schedule the segment from the seek position to the end
        if frameCount > 0 {
            playerNode.scheduleSegment(
                audioFile,
                startingFrame: clampedFrame,
                frameCount: frameCount,
                at: nil
            )
        }
        
        // Resume playback if we were playing
        if wasPlaying {
            if !engine.isRunning {
                try? engine.start()
            }
            playerNode.play()
            startDisplayLink()
        }
        
        updateNowPlayingInfo()
    }
    
    func teardown() {
        NotificationCenter.default.removeObserver(self)
        
        self.stop(queueAudio: false)

        do {
            try engine.disconnectNodeOutput(reverbNode)
            try engine.disconnectNodeOutput(pitchNode)
            try engine.disconnectNodeOutput(playerNode)

            try engine.disconnectNodeInput(reverbNode)
            try engine.disconnectNodeInput(pitchNode)
            try engine.disconnectNodeInput(playerNode)

            try engine.detach(reverbNode)
            try engine.detach(pitchNode)
            try engine.detach(playerNode)

            try engine.reset()
        } catch {
            print("Error during audio engine teardown: \(error)")
        }

        audioFile = nil
    }

    func updateTitle(title: String) {
        metaTitle = title
        updateNowPlayingInfo()
    }
        
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updateCurrentTime))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateCurrentTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let audioFile = audioFile else {
            return
        }
        
        let sampleRate = audioFile.processingFormat.sampleRate
        // Add seek offset to get the actual position in the file
        let currentFrame = playerTime.sampleTime + seekOffset
        
        // Calculate elapsed time based on frames played
        currentTime = Double(currentFrame) / sampleRate
        
        // Update Now Playing elapsed time
        if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        
        // Check if playback has finished
        if currentTime >= duration {
            self.stop()

            if isLooping {
                self.play(shouldRampVolume: false)
            }
        }
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
    
    private func rampVolume(from startVolume: Float, to endVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        // Cancel any existing ramp timer to prevent race conditions
        volumeRampTimer?.invalidate()
        
        let steps = 60 // More steps for smoother transition
        let stepDuration = duration / Double(steps)
        
        var currentStep = 0
        volumeRampTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
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
            self.engine.mainMixerNode.outputVolume = newVolume
            
            if currentStep >= steps {
                timer.invalidate()
                self.volumeRampTimer = nil
                self.engine.mainMixerNode.outputVolume = endVolume
                completion?()
            }
        }
    }

    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio was interrupted (e.g., phone call, another app taking audio)
            if isPlaying {
                self.pause()
            }
        case .ended:
            // Audio interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Resume playback if it was playing before interruption
                    self.play()
                }
            }
        @unknown default:
            break
        }
    }

    @MainActor deinit {
        teardown()
    }
}

