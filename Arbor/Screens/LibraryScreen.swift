//
//  LibraryScreen.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 11/11/25.
//

import SwiftUI
import SwiftData

struct LibraryScreen: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var player: PlayerCoordinator
    
    @Query var libraryItems: [LibraryItem]
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @State private var downloadSource: SearchResult? = nil
    @State private var downloadingItem: LibraryItem? = nil
    
    func deleteLibraryItems(_ indexSet: IndexSet) {
        for index in indexSet {
            let model = libraryItems[index]
            modelContext.delete(model)
        }
    }
    
    func onTap(_ item: LibraryItem) {
        if let absolutePath = getLocalAudioFilePath(originalUrl: item.original_url) {
            player.startPlayback(libraryItem: item, filePath: absolutePath)
            return
        }
        
        // No usable local file – fall back to re-downloading using the original URL.
        let result = SearchResult(
            title: item.title,
            artists: [item.artist],
            url: item.original_url,
            views: nil,
            duration: nil,
            isExplicit: nil,
            isVerified: nil,
            thumbnailURL: item.thumbnail_url,
            thumbnailIsSquare: item.thumbnail_is_square,
            thumbnailWidth: item.thumbnail_width,
            thumbnailHeight: item.thumbnail_height
        )
        
        downloadSource = result
        downloadingItem = item
    }
    
    var body: some View {
        Group {
            List {
                ForEach(libraryItems, id: \.persistentModelID) { item in
                    Button(action: {
                        onTap(item)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(Color("PrimaryText"))
                            
                            Text(item.artist)
                                .font(.subheadline)
                                .foregroundColor(Color("PrimaryText"))
                            
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "gauge.with.dots.needle.67percent")
                                        .font(.caption)
                                    Text(String(format: "%.2fx", item.speedRate))
                                        .font(.caption)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "tuningfork")
                                        .font(.caption)
                                    Text(String(format: "%+.0f", item.pitchCents))
                                        .font(.caption)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.caption)
                                    Text("\(Int(item.reverbMix))%")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color("SecondaryBg"))
                }
                .onDelete(perform: deleteLibraryItems)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Library")
        .alert("Unable to Play", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(
            isPresented: Binding(
                get: { downloadSource != nil },
                set: { isPresented in
                    if !isPresented {
                        downloadSource = nil
                        downloadingItem = nil
                    }
                }
            )
        ) {
            if let libraryItem = downloadingItem {
                DownloadScreen(
                    onDownloaded: { meta in
                        let _ = ensureLocalAudioFile(
                            originalUrl: libraryItem.original_url,
                            sourcePath: meta.path,
                            title: libraryItem.title,
                            artist: libraryItem.artist,
                            onMissingPhysicalFile: {
                                debugPrint("Deleting outdated library item: \(libraryItem.title)")
                                modelContext.delete(libraryItem)
                            }
                        )
                        
                        player.startPlayback(libraryItem: libraryItem, filePath: meta.path)
                    },
                    selectedResult: Binding(
                        get: { downloadSource },
                        set: { newValue in
                            downloadSource = newValue
                        }
                    )
                )
                .background(BackgroundColor.ignoresSafeArea(.all))
            } else {
                Color.clear
            }
        }
    }
}
