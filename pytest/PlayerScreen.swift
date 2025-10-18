//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import AVFoundation
import SwiftAudioPlayer
import MediaPlayer
import UIKit

class AudioPlayerWithReverb {
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var reverbNode: AVAudioUnitReverb
    private var audioFile: AVAudioFile?
    
    var isPlaying: Bool {
        return playerNode.isPlaying
    }
    
    init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        reverbNode = AVAudioUnitReverb()
        
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        engine.attach(playerNode)
        engine.attach(reverbNode)
                
        // Connect nodes: player -> reverb -> output
        engine.connect(playerNode, to: reverbNode, format: nil)
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
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func stop() {
        playerNode.stop()
        engine.stop()
    }
    
    // Adjust reverb intensity (0-100)
    func setReverbMix(_ mix: Float) {
        reverbNode.wetDryMix = min(max(mix, 0), 100)
    }
    
    // Change reverb preset
    func setReverbPreset(_ preset: AVAudioUnitReverbPreset) {
        reverbNode.loadFactoryPreset(preset)
    }
}

struct PlayerScreen: View {
    let meta: DownloadMeta
    let audioPlayer: AudioPlayerWithReverb

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

                // Play / Pause
                HStack(spacing: 24) {
                    Button(action: {
//                        viewModel.seek(to: 0)
                    }) {
                        Image(systemName: "backward.end.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            audioPlayer.play()
                        }
//                        viewModel.toggle()
                    }) {
                        Image(
                            systemName: "play.circle.fill"
//                            systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                        )
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    Button(action: {
//                        viewModel.stop()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red)
                    }
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
                VStack(spacing: 8) {
//                    HStack {
//                        Text(formattedTime(viewModel.currentTime))
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                        Spacer()
//                        Text(formattedTime(viewModel.duration))
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
                }

                // Speed
//                VStack(alignment: .leading, spacing: 8) {
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
//                // Pitch (cents)
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Pitch")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        Spacer()
//                        Button("Reset") {
//                            viewModel.setPitch(0.0)
//                        }
//                        .font(.caption)
//                        .buttonStyle(.bordered)
//                        .tint(.blue)
//                        Text(String(format: "%d cents", Int(viewModel.pitch)))
//                            .font(.subheadline)
//                            .foregroundColor(.blue)
//                    }
//                    Stepper(value: Binding(get: {
//                        Double(viewModel.pitch)
//                    }, set: { newVal in
//                        viewModel.setPitch(Float(newVal))
//                    }), in: -200...200, step: 1) {
//                        Text("Adjust pitch")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    Slider(value: Binding(get: {
//                        Double(viewModel.pitch)
//                    }, set: { newVal in
//                        viewModel.setPitch(Float(newVal))
//                    }), in: -700...500, step: 15)
//                }
//
//                // Reverb
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Reverb")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        Spacer()
//                        Button("Reset") {
//                            viewModel.setReverbWetDryMix(0.0)
//                        }
//                        .font(.caption)
//                        .buttonStyle(.bordered)
//                        .tint(.blue)
//                        Text(String(format: "%.0f%%", viewModel.reverbWetDryMix))
//                            .font(.subheadline)
//                            .foregroundColor(.blue)
//                    }
//                    Stepper(value: Binding(get: {
//                        Double(viewModel.reverbWetDryMix)
//                    }, set: { newVal in
//                        viewModel.setReverbWetDryMix(Float(newVal))
//                    }), in: 0...100, step: 1) {
//                        Text("Adjust reverb mix")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    Slider(value: Binding(get: {
//                        Double(viewModel.reverbWetDryMix)
//                    }, set: { newVal in
//                        viewModel.setReverbWetDryMix(Float(newVal))
//                    }), in: 0...100, step: 1)
//                }
            }
            .padding()
        }
    }
}


