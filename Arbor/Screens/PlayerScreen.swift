//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

struct PlayerScreen: View {
    @Binding var meta: DownloadMeta
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    
    @State private var isEditSheetPresented: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftArtist: String = ""
    
    init(meta: Binding<DownloadMeta>, audioPlayer: AudioPlayerWithReverb) {
        self._meta = meta
        self.audioPlayer = audioPlayer
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
        guard !tags.isEmpty else { return meta.title }
        return "\(meta.title) (\(tags.joined(separator: " + ")))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    SongInfo(title: meta.title, artist: meta.artist, thumbnailURL: meta.thumbnail_url, thumbnailIsSquare: meta.thumbnail_is_square)
                                        
                    // Action buttons
                    ZStack {
                        // Centered main controls
                        HStack(spacing: 16) {
                            // Rewind
                            Button(action: {
                                audioPlayer.seek(to: 0)
                                
                            }) {
                                Image(systemName: "backward.end.circle.fill")
                                    .font(.system(size: 44))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(
                                        Color("PrimaryText"),
                                        // TODO: abstract away as a secondary smth color
                                        .black.opacity(0.05)
                                    )
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
                                .font(.system(size: 56))
                                .foregroundColor(Color("PrimaryBg"))
                            }
                            
                            // Stop
                            Button(action: {
                                audioPlayer.stop()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(
                                        Color("PrimaryText"),
                                        // TODO: abstract away as a secondary smth color
                                        .black.opacity(0.05)
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Trailing loop button
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                audioPlayer.toggleLoop()
                            }) {
                                Image(
                                    systemName: audioPlayer.isLooping ? "repeat.1.circle.fill" : "repeat.circle.fill"
                                )
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    Color("PrimaryText").opacity(0.8),
                                    // TODO: abstract away as a secondary smth color
                                    .clear
                                )
                                .accessibilityLabel(
                                    audioPlayer.isLooping ? "Disable Loop" : "Enable Loop"
                                )
                            }
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
                            .accentColor(Color("PrimaryBg"))
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
                            .accentColor(Color("PrimaryBg"))
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
                            .accentColor(Color("PrimaryBg"))
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
                Button {
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    draftTitle = meta.title
                    draftArtist = meta.artist
                    isEditSheetPresented = true
                } label: {
                    Label("Edit Metadata", systemImage: "pencil")
                }
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
                            .foregroundStyle(Color("PrimaryText"))
                        
                        TextField("Title", text: $draftTitle)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(Color("Elevated"))
                            .cornerRadius(24)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artist")
                            .fontWeight(.semibold)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("PrimaryText"))
                        
                        TextField("Artist", text: $draftArtist)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(Color("Elevated"))
                            .cornerRadius(24)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal)
                }

				Spacer()

                HStack {
                    Button {
                        // Commit edits to meta on Save
                        meta.title = draftTitle
                        meta.artist = draftArtist

                        // Update now playing metadata
                        audioPlayer.updateMetadataTitle(decoratedTitle())
                        audioPlayer.updateMetadataArtist(meta.artist)
                        isEditSheetPresented = false
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
				.buttonStyle(.glassProminent)
                .tint(Color("PrimaryBg"))
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

#Preview {
	NavigationStack {
		ZStack {
			BackgroundColor
				.ignoresSafeArea()
			
			PlayerScreen(
				meta: .constant(DownloadMeta(
					path: "/Users/armaan/Library/Developer/CoreSimulator/Devices/2AF66DAD-484B-4967-8A7C-1E032023986B/data/Containers/Data/Application/23735F58-3B06-474F-8A01-E673F6ECE56D/tmp/NA-Sxu8wHE97Rk.m4a",
                    original_url: "https://www.youtube.com/watch?v=Sxu8wHE97Rk",
					title: "Ude Dil Befikre (From \"Befikre\")",
					artist: "Vishal and Sheykhar, Benny Dayal",
					thumbnail_url: "https://lh3.googleusercontent.com/viaCZKRr1hCygO8JQS6lLmhBqUVFXctO_9sOE7hwI-rS_JlYcCdqel9sAaGdQoFEFUR2R6ldsrr_c2L5=w544-h544-l90-rj",
					thumbnail_width: 544,
					thumbnail_height: 544,
					thumbnail_is_square: true
				)),
				audioPlayer: AudioPlayerWithReverb()
			)
		}
	}
}
