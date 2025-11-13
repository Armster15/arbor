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
    
    func startPlayback(libraryItem: LibraryItem, path: String) {
        debugPrint(path, libraryItem)
        
        // Tear down any existing engine before creating a new one
        audioPlayer?.unsubscribeUpdates()
        audioPlayer = nil
        
        let newAudioPlayer = AudioPlayerWithReverb()
        lastLibraryItem = libraryItem
        
        let artworkURL = libraryItem.thumbnail_url.flatMap { URL(string: $0) }
        
        newAudioPlayer.startSavedAudio(filePath: path)
        
        newAudioPlayer.updateMetadataTitle(libraryItem.title)
        newAudioPlayer.updateMetadataArtist(libraryItem.artist)
        if let artworkURL = artworkURL {
            newAudioPlayer.updateMetadataArtwork(url: artworkURL)
        }
        // Apply audio parameters from the library item
        newAudioPlayer.setSpeedRate(libraryItem.speedRate)
        newAudioPlayer.setPitchByCents(libraryItem.pitchCents)
        newAudioPlayer.setReverbMix(libraryItem.reverbMix)
        
        audioPlayer = newAudioPlayer
        
        open()
    }
}
