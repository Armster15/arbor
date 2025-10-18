//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import AVFoundation
import MediaPlayer


struct PlayerScreen: View {
    let meta: DownloadMeta
    @ObservedObject var audioPlayer: MetronomeAudioPlayer
    
    // Local state to track slider values since MetronomeAudioPlayer doesn't expose them
    @State private var speedRate: Float = 1.0
    @State private var pitchRate: Float = 1.0

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
                                    speedRate = 1.0
                                    audioPlayer.setRate(rate: speedRate)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                .opacity(speedRate == 1.0 ? 0 : 1)
                            
                            Spacer()
                            
                            Text(String(format: "%.2fx", speedRate))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(speedRate)
                                    },
                                    set: { newVal in
                                        // Slider sends continuous values while dragging, so we snap to the nearest 0.05 to enforce stepping.
                                        let snapped = (newVal / 0.05).rounded() * 0.05
                                        speedRate = Float(snapped)
                                        audioPlayer.setRate(rate: speedRate)
                                    }
                                ),
                                in: 0.25...2.0,
                                step: 0.05
                            )
                            .frame(maxWidth: .infinity)
                            
                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(speedRate)
                                    },
                                    set: { newVal in
                                        speedRate = Float(newVal)
                                        audioPlayer.setRate(rate: speedRate)
                                    }
                                ),
                                in: 0.25...2.0,
                                step: 0.01,
                            ) {}
                            .fixedSize()
                        }
                    }

                    
                    // Pitch
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                                Button("Reset") {
                                    pitchRate = 1.0
                                    audioPlayer.setPitch(rate: pitchRate)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                .opacity(pitchRate == 1.0 ? 0 : 1)
                            
                            Spacer()
                            
                            Text(String(format: "%.2fx", pitchRate))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Slider(
                                value: Binding(
                                    get: {
                                        Double(pitchRate)
                                    },
                                    set: { newVal in
                                        // Slider sends continuous values while dragging, so we snap to the nearest 0.05 to enforce stepping.
                                        let snapped = (newVal / 0.05).rounded() * 0.05
                                        pitchRate = Float(snapped)
                                        audioPlayer.setPitch(rate: pitchRate)
                                    }
                                ),
                                in: 0.5...2.0,
                                step: 0.05
                            )
                            .frame(maxWidth: .infinity)
                            
                            Stepper(
                                value: Binding(
                                    get: {
                                        Double(pitchRate)
                                    },
                                    set: { newVal in
                                        pitchRate = Float(newVal)
                                        audioPlayer.setPitch(rate: pitchRate)
                                    }
                                ),
                                in: 0.5...2.0,
                                step: 0.01,
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
