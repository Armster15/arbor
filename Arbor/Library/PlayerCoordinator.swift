//
//  PlayerCoordinator.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 11/11/25.
//

import SwiftUI
import SDWebImage
import Combine

@MainActor
final class PlayerCoordinator: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var audioPlayer: AudioPlayerWithReverb? = nil
    @Published var libraryItem: LibraryItem? = nil
    @Published var filePath: String? = nil
    @Published var artworkImage: UIImage? = nil
    @Published var artworkURL: URL? = nil

    private var lastFM: LastFMSession?
    private let scrobbleQueue = ScrobbleQueue()
    private var scrobbleState: ScrobbleState?
    private var audioPlayerCancellables = Set<AnyCancellable>() // for monitoring changes to `duration`, `currentTime`, and `isPlaying` properties
    private var lastFMCancellable: AnyCancellable? // for monitoring changes to `manager` and `isScrobblingEnabled` properties
    private var lastPlaybackTime: Double = 0
    private var didReturnToStart = false

    // for setting the global LastFM session
    func attach(lastFM: LastFMSession) {
        self.lastFM = lastFM
        lastFMCancellable = Publishers.CombineLatest(lastFM.$manager, lastFM.$isScrobblingEnabled)
            .sink { [weak self] manager, isEnabled in
                guard let self = self, isEnabled else { return }
                Task {
                    await self.scrobbleQueue.flushIfNeeded(manager: manager)
                }
            }
    }

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
        lastPlaybackTime = 0
        didReturnToStart = false

        // Load artwork image so we don't reconstruct it on every rerender in the bottom tab view accessory of ContentView
        let nextArtworkURL = libraryItem.thumbnail_url.flatMap { URL(string: $0) }
        if artworkURL != nextArtworkURL {
            artworkURL = nextArtworkURL
            artworkImage = nil
            if let url = nextArtworkURL {
                SDWebImageManager.shared.loadImage(
                    with: url,
                    options: [.highPriority, .retryFailed, .scaleDownLargeImages],
                    progress: nil
                ) { [weak self] image, _, error, _, finished, _ in
                    guard let self = self, error == nil, finished, let image else { return }
                    Task { @MainActor in
                        if self.artworkURL == url {
                            self.artworkImage = image
                        }
                    }
                }
            }
        }
        
        // Tear down any existing engine before creating a new one
        audioPlayer?.unsubscribeUpdates()
        audioPlayer = nil
        
        let newAudioPlayer = AudioPlayerWithReverb()
        
        let artworkURL = libraryItem.thumbnail_url.flatMap { URL(string: $0) }
        
        newAudioPlayer.startSavedAudio(filePath: filePath)
        
        newAudioPlayer.updateMetadataTitle(libraryItem.title)
        newAudioPlayer.updateMetadataArtist(formatArtists(libraryItem.artists))
        if let artworkURL = artworkURL {
            newAudioPlayer.updateMetadataArtwork(url: artworkURL)
        }
        // Apply audio parameters from the library item
        newAudioPlayer.setSpeedRate(libraryItem.speedRate)
        newAudioPlayer.setPitchByCents(libraryItem.pitchCents)
        newAudioPlayer.setReverbMix(libraryItem.reverbMix)
        
        self.audioPlayer = newAudioPlayer
        
        monitorAudioPlayerChanges(for: newAudioPlayer, libraryItem: libraryItem)
        
        open()
    }

    private func monitorAudioPlayerChanges(for audioPlayer: AudioPlayerWithReverb, libraryItem: LibraryItem) {
        audioPlayerCancellables.removeAll()
        scrobbleState = ScrobbleState(libraryItem: libraryItem)
        lastPlaybackTime = 0
        didReturnToStart = false

        debugPrint("Monitoring audio player changes for library item: \(libraryItem.title)")

        // monitor changes to `duration`
        audioPlayer.$duration
            .sink { [weak self] duration in
                self?.scrobbleState?.updateDuration(duration)
            }
            .store(in: &audioPlayerCancellables)

        // monitor changes to `currentTime` and `isPlaying`
        Publishers.CombineLatest(audioPlayer.$currentTime, audioPlayer.$isPlaying)
            .sink { [weak self] currentTime, isPlaying in
                self?.handleScrobbleProgress(currentTime: currentTime, isPlaying: isPlaying)
            }
            .store(in: &audioPlayerCancellables)
    }

    private func handleScrobbleProgress(currentTime: Double, isPlaying: Bool) {
        handleScrobbleResetIfNeeded(currentTime: currentTime, isPlaying: isPlaying)
        guard let scrobbleState, 
              scrobbleState.shouldScrobble(currentTime: currentTime, isPlaying: isPlaying) else {
            return
        }

        guard let lastFM,
              lastFM.isAuthenticated,
              lastFM.isScrobblingEnabled else {
            return
        }

        debugPrint("Scrobbling library item: \(libraryItem?.title ?? "Unknown")")

        scrobbleState.markScrobbled()
        let scrobble = scrobbleState.toCachedScrobble()

        Task {
            await scrobbleQueue.enqueue(scrobble)
            await scrobbleQueue.flushIfNeeded(manager: lastFM.manager)
        }
    }

    private func handleScrobbleResetIfNeeded(currentTime: Double, isPlaying: Bool) {
        if currentTime <= 0.05, lastPlaybackTime > 5.0 {
            didReturnToStart = true
        }

        if isPlaying, didReturnToStart, let libraryItem {
            didReturnToStart = false
            scrobbleState = ScrobbleState(libraryItem: libraryItem)
            if let scrobbleState {
                scrobbleState.updateDuration(audioPlayer?.duration ?? 0)
            }
        }

        lastPlaybackTime = currentTime
    }
}
