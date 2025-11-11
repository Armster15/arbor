//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

struct PlayerScreen: View {
    let meta: DownloadMeta
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    
    @State private var isEditSheetPresented: Bool = false
    @State private var overridenTitle: String
    @State private var overridenArtist: String
    
    init(meta: DownloadMeta, audioPlayer: AudioPlayerWithReverb) {
        self.meta = meta
        self.audioPlayer = audioPlayer
        _overridenTitle = State(initialValue: meta.title)
        _overridenArtist = State(initialValue: meta.artist ?? "")
    }

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
        guard !tags.isEmpty else { return overridenTitle }
        return "\(overridenTitle) (\(tags.joined(separator: " + ")))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    SongInfo(title: overridenTitle, artist: overridenArtist.isEmpty ? nil : overridenArtist, thumbnailURL: meta.thumbnail_url, thumbnailIsSquare: meta.thumbnail_is_square)
                                        
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
                        
                        Slider(
                            value: $audioPlayer.currentTime,
                            in: 0...audioPlayer.duration,
                        )
                        .disabled(true)
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
                                in: -800.0...800.0,
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
                                in: -800.0...800.0,
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
                            
                            Text("\(Int(audioPlayer.reverbMix))%")
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
                                        let snapped = (newVal / 5.0).rounded() * 5.0
                                        audioPlayer.setReverbMix(Float(snapped))
                                    }
                                ),
                                in: 0.0...100.0,
                                step: 5
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
                                in: 0.0...100.0,
                                step: 1,
                            ) {}
                            .fixedSize()
                        }
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu(content: {
                    Button {
                        isEditSheetPresented = true
                    } label: {
                        Label("Edit Metadata", systemImage: "pencil")
                    }

                    Button {
                        print("private listen")
                    } label: {
                        Label("Listen Privately", systemImage: "eye.slash.fill")
                    }

                    Button(role: .destructive) {
                        print("cache")
                    } label: {
                        Label("Remove from Cache", systemImage: "trash.fill")
                    }
                }, label: {
                    Image(systemName: "ellipsis")
                })
             }

        }
        .onChange(of: audioPlayer.speedRate) { _, _ in
            audioPlayer.updateMetadataTitle(decoratedTitle())
        }
        .onChange(of: audioPlayer.reverbMix) { _, _ in
            audioPlayer.updateMetadataTitle(decoratedTitle())
        }
        .sheet(isPresented: $isEditSheetPresented) {
			VStack(spacing: 32) {
                Text("Edit Metadata")
                    .font(.headline)
                    .padding(.top, 24)
            
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .fontWeight(.semibold)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.displayP3, red: 0.03120, green: 0.09596, blue: 0.00000, opacity: 1.0))
                        
                        
                        TextField("Title", text: $overridenTitle)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(
                                Color(.displayP3, red: 0.03120, green: 0.09596, blue: 0.00000, opacity: 0.1)
                            )
                            .cornerRadius(24)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artist")
                            .fontWeight(.semibold)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.displayP3, red: 0.03120, green: 0.09596, blue: 0.00000, opacity: 1.0))
                        
                        
                        TextField("Artist", text: $overridenArtist)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(
                                Color(.displayP3, red: 0.03120, green: 0.09596, blue: 0.00000, opacity: 0.1)
                            )
                            .cornerRadius(24)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal)
                }

				Spacer()

                HStack {
                    Button {
                        // Update now playing metadata
                        audioPlayer.updateMetadataTitle(decoratedTitle())
                        let artistToSet: String? = overridenArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : overridenArtist
                        audioPlayer.updateMetadataArtist(artistToSet)
                        isEditSheetPresented = false
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
				.buttonStyle(.glassProminent)
				.padding(.horizontal)
				.padding(.bottom)
                
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
