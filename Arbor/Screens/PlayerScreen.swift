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
    
    private func sanitizeForFilename(_ string: String) -> String {
        // Remove or replace characters that are unsafe for filenames
        let unsafeCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = string.components(separatedBy: unsafeCharacters).joined(separator: "_")
        
        // Also replace newlines and trim whitespace
        let cleaned = sanitized.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit length to avoid extremely long filenames (max 100 chars per field)
        return String(cleaned.prefix(100))
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
        let localFile = getLibraryLocalFile(originalUrl: originalUrl)
        
        var fileFound = false
        
        if let existingFile = localFile {
            // Reconstruct absolute path from the stored relative path
            let docsURL = URL.documentsDirectory
            let fileURL = docsURL.appendingPathComponent(existingFile.relativePath)
            let absolutePath = fileURL.path
            
            self.filePath = absolutePath
            
            // Check if the file still exists because if it doesn't we need to delete this outdated library item
            if !FileManager.default.fileExists(atPath: absolutePath) {
                debugPrint("Deleting outdated library item: \(item.title)")
                modelContext.delete(item)
            } else {
                fileFound = true
                debugPrint("Reusing existing local file: \(absolutePath)")
            }
        }
        
        if !fileFound {
            // No existing file, copy to permanent location
            let sourceURL = URL(fileURLWithPath: filePath)
            let ext = sourceURL.pathExtension
            let timestamp = Int(Date().timeIntervalSince1970)
            let safeTitle = sanitizeForFilename(item.title)
            let safeArtist = sanitizeForFilename(item.artist)
            let newName = "\(safeTitle)-\(safeArtist)-\(timestamp).\(ext)"
            
            let docsURL = URL.documentsDirectory
            let newURL = docsURL.appendingPathComponent(newName)
            
            try? FileManager.default.copyItem(at: sourceURL, to: newURL)
            let absolutePath = newURL.path
            self.filePath = absolutePath
            
            debugPrint("Saved audio file to more permanent location: \(absolutePath)")
            
            // Store only the path relative to the Documents directory
            let relativePath = absolutePath.replacingOccurrences(of: docsURL.path + "/", with: "")
            let model = LibraryLocalFile(originalUrl: item.original_url, relativePath: relativePath)
            saveLibraryLocalFile(model)
        }
        
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
                        libraryItem.title = draftTitle
                        libraryItem.artist = draftArtist

                        // Update now playing metadata
                        audioPlayer.updateMetadataTitle(decoratedTitle())
                        audioPlayer.updateMetadataArtist(libraryItem.artist)
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
