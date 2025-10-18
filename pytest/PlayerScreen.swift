//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayerWithReverb: ObservableObject {
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    
    private var pitchNode: AVAudioUnitTimePitch
    private var reverbNode: AVAudioUnitReverb
    
    @Published public var isPlaying: Bool = false
    @Published public var speedRate: Float = 1.0
    @Published public var reverbMix: Float = 0.0
    @Published public var pitchCents: Float = 0.0
    @Published public var isLooping: Bool = false

    @Published public var currentTime: TimeInterval = 0.0
    @Published public var duration: TimeInterval = 0.0
    private var displayLink: CADisplayLink? // timer that synchronizes with the screen's refresh rate
    private var startFrame: AVAudioFramePosition = 0
    private var startTime: TimeInterval = 0

    init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()
        
        setupAudioEngine()
        
        // Default parameters
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
    
    func loadAudio(url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
        
        // Calculate duration
        if let file = audioFile {
            let sampleRate = file.processingFormat.sampleRate
            let frameCount = file.length
            duration = Double(frameCount) / sampleRate
        }
    }
    
    func play() {
        guard let audioFile = audioFile else { return }
        
        // Store the starting frame position
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            startFrame = playerTime.sampleTime
            startTime = CACurrentMediaTime()
        }
        
        playerNode.scheduleFile(audioFile, at: nil)
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        playerNode.play()
        isPlaying = true
        
        startDisplayLink()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopDisplayLink()
    }

    func toggleLoop() {
        isLooping = !isLooping
    }
    
    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
    }
    
    func teardown() {
        stop()

        engine.reset()
        engine.disconnectNodeInput(reverbNode)
        engine.disconnectNodeInput(pitchNode)
        engine.disconnectNodeInput(playerNode)

        engine.detach(reverbNode)
        engine.detach(pitchNode)
        engine.detach(playerNode)

        audioFile = nil
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
        let currentFrame = playerTime.sampleTime
        
        // Calculate elapsed time based on frames played
        currentTime = Double(currentFrame) / sampleRate
        
        // Check if playback has finished
        if currentTime >= duration {
            stop()

            if isLooping {
                play()
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

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    // Metadata header
                    VStack(spacing: 16) {
                        if let thumbnailUrl = meta.thumbnail_url, let isSquare = meta.thumbnail_is_square {
                            if isSquare == true {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: URL(string: thumbnailUrl)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 180, height: 180)
                                            .clipped()
                                            .cornerRadius(12)
                                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
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
                                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
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
                            audioPlayer.stop()
                            audioPlayer.play()
                            
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
                                systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill"
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
                                systemName: audioPlayer.isLooping ? "repeat.circle.fill" : "repeat.circle"
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
                                step: 50,
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
    }
}

private func formattedTime(_ seconds: Double) -> String {
    guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
    let s = Int(seconds.rounded())
    let mins = s / 60
    let secs = s % 60
    return String(format: "%d:%02d", mins, secs)
}

