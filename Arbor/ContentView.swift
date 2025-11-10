//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import UIKit

struct DownloadMeta: Decodable {
    let path: String
    let title: String
    let artist: String?
    let thumbnail_url: String?
    let thumbnail_width: Int?
    let thumbnail_height: Int?
    let thumbnail_is_square: Bool?
}

let BackgroundColor = LinearGradient(
    gradient: Gradient(colors: [
        Color(red: 239/255, green: 242/255, blue: 225/255),
        Color(red: 249/255, green: 255/255, blue: 212/255),
    ]),
    startPoint: .top,
    endPoint: .bottom
)

struct ContentView: View {
    @State private var navPath: [Route] = []
    @State private var lastDownloadMeta: DownloadMeta? = nil
    @State private var audioPlayer: AudioPlayerWithReverb? = nil
    @State private var searchText: String = "" // TODO: remove
    
    init() {
        let titleColor = UIColor(red: 3/255, green: 25/255, blue: 0/255, alpha: 1.0)
        let font = UIFont(name: "Spicy Rice", size: 32)!
        
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: titleColor, .font: font]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: titleColor, .font: font]        
    }
    
    private enum Route: Hashable {
        case player
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            HomeScreen(
                canOpenPlayer: lastDownloadMeta != nil,
                openPlayerAction: { if navPath.last != .player { navPath.append(.player) } },
                onDownloaded: { meta in
                    debugPrint(meta)
                    lastDownloadMeta = meta
                    
                    // Tear down any existing engine before creating a new one
                    audioPlayer?.unsubscribeUpdates()
                    audioPlayer = nil

                    let newAudioPlayer = AudioPlayerWithReverb()
                    let artworkURL = meta.thumbnail_url.flatMap { URL(string: $0) }
                    
                    newAudioPlayer.startSavedAudio(filePath: meta.path)
                    
                    newAudioPlayer.updateMetadataTitle(meta.title)
                    newAudioPlayer.updateMetadataArtist(meta.artist)
                    if let artworkURL = artworkURL {
                        newAudioPlayer.updateMetadataArtwork(url: artworkURL)
                    }
                    
                    audioPlayer = newAudioPlayer
                    
                    if navPath.last != .player { navPath.append(.player) }
                }
            )
            .navigationDestination(for: Route.self) { route in
                ZStack {
                    BackgroundColor // <- Background for all non root views
                        .ignoresSafeArea()
                    
                    Group {
                        switch route {
                        case .player:
                            PlayerScreen(meta: lastDownloadMeta!, audioPlayer: audioPlayer!)
                        }
                    }
                }
            }
            .background(BackgroundColor.ignoresSafeArea(.all)) // for root view
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {} label: { Label("New", systemImage: "music.note.square.stack.fill") }
                }
                
                ToolbarSpacer(placement: .bottomBar)
                
                DefaultToolbarItem(kind: .search, placement: .bottomBar)

            }
        }
    }
}

#Preview {
    ContentView()
}
