//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import AVFoundation
import AVKit
import SwiftAudioPlayer
import Foundation
import UIKit

struct ContentView: View {
    @State private var audioFilePath: String?
    @StateObject private var saViewModel = SAPlayerViewModel()
    @State private var navPath: [Route] = []
	
	private struct DownloadMeta: Decodable {
		let path: String
		let title: String?
		let artist: String?
		let thumbnail_url: String?
		let thumbnail_width: Int?
		let thumbnail_height: Int?
		let thumbnail_is_square: Bool?
	}
    
    private enum Route: Hashable {
        case player
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            HomeScreen(
                canOpenPlayer: audioFilePath != nil,
                openPlayerAction: { if navPath.last != .player { navPath.append(.player) } },
                onDownloaded: { meta in
                    audioFilePath = meta.path
                    setupAudioPlayer(filePath: meta.path)
                    let artworkURL = meta.thumbnail_url.flatMap { URL(string: $0) }
                    saViewModel.setMetadata(title: meta.title, artist: meta.artist, artworkURL: artworkURL)
                    if navPath.last != .player { navPath.append(.player) }
                }
            )
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Audio Downloader")
            
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .player:
                    PlayerScreen(viewModel: saViewModel)
                }
            }
        }
    }
    
    private func setupAudioPlayer(filePath: String) {
        // Initialize SAPlayer with saved file and attach TimePitch for speed/pitch and Reverb effect
        let timePitch = AVAudioUnitTimePitch()
        let reverb = AVAudioUnitReverb()
        reverb.wetDryMix = 0
        SAPlayer.shared.audioModifiers = [timePitch, reverb]
        saViewModel.setRate(1.0)
        saViewModel.setPitch(0.0)
        saViewModel.setReverbWetDryMix(0.0)
        saViewModel.startSavedAudio(filePath: filePath)
    }
}

#Preview {
    ContentView()
}
