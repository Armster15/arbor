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
    @Published var libraryItem: LibraryItem? = nil
    @Published var filePath: String? = nil

    public func open()  {
        if canShowPlayer {
            isPresented = true
        }
    }
    
    public func close() { isPresented = false }
    
    public var canShowPlayer: Bool { audioPlayer != nil && libraryItem != nil && filePath != nil }
    
    public func startPlayback(libraryItem: LibraryItem, filePath: String) {
        debugPrint(filePath, libraryItem)

        self.filePath = filePath
        self.libraryItem = libraryItem
        
        // Tear down any existing engine before creating a new one
        audioPlayer?.unsubscribeUpdates()
        audioPlayer = nil
        
        let newAudioPlayer = AudioPlayerWithReverb()
        
        let artworkURL = libraryItem.thumbnail_url.flatMap { URL(string: $0) }
        
        newAudioPlayer.startSavedAudio(filePath: filePath)
        
        newAudioPlayer.updateMetadataTitle(libraryItem.title)
        newAudioPlayer.updateMetadataArtist(libraryItem.artist)
        if let artworkURL = artworkURL {
            newAudioPlayer.updateMetadataArtwork(url: artworkURL)
        }
        // Apply audio parameters from the library item
        newAudioPlayer.setSpeedRate(libraryItem.speedRate)
        newAudioPlayer.setPitchByCents(libraryItem.pitchCents)
        newAudioPlayer.setReverbMix(libraryItem.reverbMix)
        
        self.audioPlayer = newAudioPlayer
        
        open()
    }
}
