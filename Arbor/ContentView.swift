//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI

struct DownloadMeta: Decodable {
    let path: String
    let title: String
    let artist: String?
    let thumbnail_url: String?
    let thumbnail_width: Int?
    let thumbnail_height: Int?
    let thumbnail_is_square: Bool?
}

struct ContentView: View {
    @State private var navPath: [Route] = []
    @State private var lastDownloadMeta: DownloadMeta? = nil
    @State private var audioPlayer: AudioPlayerWithReverb? = nil
    
    private enum Route: Hashable {
        case player
    }
    
    var body: some View {
        TabView {
            Tab("Explore", systemImage: "text.rectangle.page") {
                NavigationStack(path: $navPath) {
                    HomeScreen(
                        canOpenPlayer: lastDownloadMeta != nil,
                        openPlayerAction: { if navPath.last != .player { navPath.append(.player) } },
                        onDownloaded: { meta in
                            debugPrint(meta)
                            lastDownloadMeta = meta
                            
                            // Tear down any existing engine before creating a new one
                            audioPlayer?.teardown()
                            audioPlayer = nil
                            
                            let newAudioPlayer = AudioPlayerWithReverb()
                            try? newAudioPlayer.loadAudio(
                                url: URL(string: meta.path)!,
                            )
                            
                            newAudioPlayer.loadMetadataStrings(title: meta.title, artist: meta.artist)
                            
                            let artworkURL = meta.thumbnail_url.flatMap { URL(string: $0) }
                            if let artworkURL = artworkURL {
                                newAudioPlayer.loadMetadataArtwork(url: artworkURL)
                            }
                            
                            audioPlayer = newAudioPlayer
                            
                            if navPath.last != .player { navPath.append(.player) }
                        }
                    )
                    
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .player:
                            PlayerScreen(meta: lastDownloadMeta!, audioPlayer: audioPlayer!)
                        }
                    }
                }
            }
            
            Tab("My Library", systemImage: "music.note.square.stack") {
                VStack {
                    Text("TODO")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
