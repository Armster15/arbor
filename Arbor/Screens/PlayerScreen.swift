//
//  PlayerView.swift
//  pytest
//

import SwiftUI
import SwiftData
import SDWebImage
import SDWebImageSwiftUI

// this is so we can provide the actual PlayerScreen (__PlayerScreen)
// with non-nullable values for libraryItem, audioPlayer, and filePath
struct PlayerScreen: View {
    @EnvironmentObject var player: PlayerCoordinator
        
    var body: some View {
        Group {
            if let libraryItem = player.libraryItem,
               let audioPlayer = player.audioPlayer,
               let filePath = player.filePath {
                __PlayerScreen(
                    libraryItem: libraryItem,
                    audioPlayer: audioPlayer,
                    filePath: Binding(
                        get: { filePath },
                        set: { player.filePath = $0 }
                    )
                )
            } else {
                EmptyView()
            }
        }
    }
}

struct __PlayerScreen: View {
    @Bindable var libraryItem: LibraryItem
    @ObservedObject var audioPlayer: AudioPlayerWithReverb
    @Binding var filePath: String
    
    @State private var isEditSheetPresented: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftArtist: String = ""
    @State private var isScrubbing: Bool = false
    
    @Environment(\.modelContext) var modelContext
    
    init(libraryItem: LibraryItem, audioPlayer: AudioPlayerWithReverb, filePath: Binding<String>) {
        self.libraryItem = libraryItem
        self.audioPlayer = audioPlayer
        self._filePath = filePath
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
        guard !tags.isEmpty else { return libraryItem.title }
        return "\(libraryItem.title) (\(tags.joined(separator: " + ")))"
    }
    
    private func saveToLibrary() {
        let SHOULD_COPY = true

        // if SHOULD_COPY is true, it will save a new library item
        // else if false it will edit the existing library item
        let item = SHOULD_COPY ? LibraryItem(copyOf: libraryItem) : libraryItem
        
        item.speedRate = audioPlayer.speedRate
        item.pitchCents = audioPlayer.pitchCents
        item.reverbMix = audioPlayer.reverbMix
        
        let originalUrl = item.original_url
        
        let absolutePath = ensureLocalAudioFile(
            originalUrl: originalUrl,
            sourcePath: filePath,
            title: item.title,
            artist: item.artist,
            onMissingPhysicalFile: {
                debugPrint("Deleting outdated library item: \(item.title)")
                modelContext.delete(item)
            }
        )
        
        self.filePath = absolutePath
        
        if SHOULD_COPY {
            modelContext.insert(item)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    SongInfo(
                        title: libraryItem.title,
                        artist: libraryItem.artist,
                        thumbnailURL: libraryItem.thumbnail_url,
                        thumbnailIsSquare: libraryItem.thumbnail_is_square,
                        thumbnailForceSquare: false,
                        thumbnailHasContextMenu: true
                    )
                                        
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
                                        Color("SecondaryBg")
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
                                        Color("SecondaryBg")
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
                    Scrubber(
                        value: $audioPlayer.currentTime,
                        inRange: 0...max(audioPlayer.duration, 0.01),
                        activeFillColor: Color("PrimaryBg"),
                        fillColor: Color("PrimaryBg").opacity(0.8),
                        emptyColor: Color("PrimaryBg").opacity(0.2),
                        height: 30,
                        onEditingChanged: { editing in
                            isScrubbing = editing
                            if !editing {
                                audioPlayer.seek(to: audioPlayer.currentTime)
                            }
                        }
                    )
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
                    saveToLibrary()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    draftTitle = libraryItem.title
                    draftArtist = libraryItem.artist
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
                    LabeledTextField(
                        label: "Title",
                        placeholder: "Title",
                        text: $draftTitle,
                        isSecure: false,
                        textContentType: nil,
                        keyboardType: .default,
                        autocapitalization: .words,
                        disableAutocorrection: true
                    )
                    
                    LabeledTextField(
                        label: "Artist",
                        placeholder: "Artist",
                        text: $draftArtist,
                        isSecure: false,
                        textContentType: nil,
                        keyboardType: .default,
                        autocapitalization: .words,
                        disableAutocorrection: true
                    )
                }

				Spacer()

                PrimaryActionButton(
                    title: "Save",
                    isLoading: false,
                    isDisabled: false,
                    action: {
                        // Commit edits to meta on Save
                        libraryItem.title = draftTitle
                        libraryItem.artist = draftArtist

                        // Update now playing metadata
                        audioPlayer.updateMetadataTitle(decoratedTitle())
                        audioPlayer.updateMetadataArtist(libraryItem.artist)
                        isEditSheetPresented = false
                    }
                )
                
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
	NavigationStack {
		ZStack {
			BackgroundColor
				.ignoresSafeArea()
			
			__PlayerScreen(
				libraryItem: LibraryItem(
                    original_url: "https://www.youtube.com/watch?v=Sxu8wHE97Rk",
                    title: "Ude Dil Befikre (From \"Befikre\")",
                    artist: "Vishal and Sheykhar, Benny Dayal",
                    thumbnail_url: "https://lh3.googleusercontent.com/viaCZKRr1hCygO8JQS6lLmhBqUVFXctO_9sOE7hwI-rS_JlYcCdqel9sAaGdQoFEFUR2R6ldsrr_c2L5=w544-h544-l90-rj",
                    thumbnail_width: 544,
                    thumbnail_height: 544,
                    thumbnail_is_square: true
                ),
				audioPlayer: AudioPlayerWithReverb(),
                filePath: Binding(
                    get: { "" },
                    set: { _ in }
                )
			)
		}
	}
}
