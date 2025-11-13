//
//  PlayerCoordinator.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 11/11/25.
//

import SwiftUI

@MainActor
final class PlayerCoordinator: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var audioPlayer: AudioPlayerWithReverb? = nil
    @Published var lastLibraryItem: LibraryItem? = nil

    func open()  { isPresented = true }
    func close() { isPresented = false }
    
    func startPlayback(from meta: DownloadMeta) {
        debugPrint(meta)
        
        // Tear down any existing engine before creating a new one
        audioPlayer?.unsubscribeUpdates()
        audioPlayer = nil
        
        let newAudioPlayer = AudioPlayerWithReverb()
        let newLibraryItem = LibraryItem(meta: meta)
        lastLibraryItem = newLibraryItem
        
        let artworkURL = newLibraryItem.thumbnail_url.flatMap { URL(string: $0) }
        
        newAudioPlayer.startSavedAudio(filePath: meta.path)
        
        newAudioPlayer.updateMetadataTitle(newLibraryItem.title)
        newAudioPlayer.updateMetadataArtist(newLibraryItem.artist)
        if let artworkURL = artworkURL {
            newAudioPlayer.updateMetadataArtwork(url: artworkURL)
        }
        
        audioPlayer = newAudioPlayer
        
        open()
    }
}
