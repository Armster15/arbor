//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import AVFoundation
import SwiftAudioPlayer
import MediaPlayer
import UIKit

@MainActor
class AudioPlayerWithReverb: ObservableObject {
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    
    private var pitchNode: AVAudioUnitTimePitch
    private var reverbNode: AVAudioUnitReverb
    
    @Published public var isPlaying: Bool = false
    @Published public var reverbMix: Float = 0.0
    @Published public var pitchCents: Float = 0.0

    init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()
        
        setupAudioEngine()
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
    }
    
    func play() {
        guard let audioFile = audioFile else { return }
        
        playerNode.scheduleFile(audioFile, at: nil)
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        playerNode.play()
        isPlaying = true
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
    }
    
    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
    }
    
    // Adjust pitch in cents (-2400...+2400). 100 cents = 1 semitone.
    func setPitchByCents(_ cents: Float) {
        pitchNode.pitch = min(max(cents, -2400), 2400)
        pitchCents = pitchNode.pitch
    }
        
    // Adjust reverb intensity (0-100)
    func setReverbMix(_ mix: Float) {
        reverbNode.wetDryMix = min(max(mix, 0), 100)
        reverbMix = reverbNode.wetDryMix
    }
}

struct PlayerScreen: View {
    let meta: DownloadMeta
    @ObservedObject var audioPlayer: AudioPlayerWithReverb

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
        let s = Int(seconds.rounded())
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        ScrollView {
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
                        //                        viewModel.toggle()
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
                        //                        viewModel.toggleLoop()
                    }) {
                        Image(systemName: "repeat.circle"
                              //                        viewModel.isLooping ? "repeat.circle.fill" : "repeat.circle"
                        )
                        .font(.system(size: 44))
                        .foregroundColor(
                            .secondary
                            //                                viewModel.isLooping ? .green : .secondary
                        )
                        .accessibilityLabel(
                            "Enable Loop"
                            //                                viewModel.isLooping ? "Disable Loop" : "Enable Loop"
                        )
                    }
                }
                
                // Scrubber
                //                VStack(spacing: 8) {
                //                    HStack {
                //                        Text(formattedTime(viewModel.currentTime))
                //                            .font(.caption)
                //                            .foregroundColor(.secondary)
                //                        Spacer()
                //                        Text(formattedTime(viewModel.duration))
                //                            .font(.caption)
                //                            .foregroundColor(.secondary)
                //                    }
                //                }
                
                VStack(alignment: .leading, spacing: 8) {
                    //                    // Speed
                    //                    HStack {
                    //                        Text("Speed")
                    //                            .font(.subheadline)
                    //                            .fontWeight(.medium)
                    //                        Spacer()
                    //                        Button("Reset") {
                    //                            viewModel.setRate(1.0)
                    //                        }
                    //                        .font(.caption)
                    //                        .buttonStyle(.bordered)
                    //                        .tint(.blue)
                    //                        Text(String(format: "%.2fx", viewModel.rate))
                    //                            .font(.subheadline)
                    //                            .foregroundColor(.blue)
                    //                    }
                    //                    Stepper(value: Binding(get: {
                    //                        Double(viewModel.rate)
                    //                    }, set: { newVal in
                    //                        viewModel.setRate(Float(newVal))
                    //                    }), in: 0.25...3.0, step: 0.01) {
                    //                        Text("Adjust speed")
                    //                            .font(.caption)
                    //                            .foregroundColor(.secondary)
                    //                    }
                    //                    Slider(value: Binding(get: {
                    //                        Double(viewModel.rate)
                    //                    }, set: { newVal in
                    //                        viewModel.setRate(Float(newVal))
                    //                    }), in: 0.25...3.0, step: 0.01)
                    //                }
                    //
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
                            // `flex: 1` (???)
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
                            // `flex: 1` (???)
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


