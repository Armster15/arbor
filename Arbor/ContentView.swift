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
        Color("GradientStart"),
        Color("GradientEnd"),
    ]),
    startPoint: .top,
    endPoint: .bottom
)

struct ContentView: View {
    @State private var navPath: [Route] = []
    @State private var lastDownloadMeta: DownloadMeta? = nil
    @State private var audioPlayer: AudioPlayerWithReverb? = nil
    
    private var canOpenPlayer: Bool {
        lastDownloadMeta != nil
    }

    private var isPlayerScreenOpen: Bool {
        navPath.last == .player
    }
    
    private func openPlayer() {
        if !isPlayerScreenOpen {
            navPath.append(.player)
        }
    }
    
    init() {
        let titleColor = UIColor(named: "Primary")!
        let font = UIFont(name: "Spicy Rice", size: 32)!
        
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: titleColor, .font: font]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: titleColor, .font: font]        
    }
    
    private enum Route: Hashable {
        case player
    }
    
    var body: some View {
        TabView {
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack(path: $navPath) {
                    HomeScreen(
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
                            
                            openPlayer()
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
                }
            }

            Tab("Library", systemImage: "music.note.square.stack.fill") {
                NavigationStack(path: $navPath) {
                    VStack {
                        Text("Library")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(BackgroundColor.ignoresSafeArea(.all)) // for root view
                }
            }
        }
        .tabViewBottomAccessory {
            if canOpenPlayer && !isPlayerScreenOpen {
                HStack {
                    Button(action: openPlayer) {
                        HStack(spacing: 12) {
                            SongImage(
                                width: 40,
                                height: 40,
                                thumbnailURL: lastDownloadMeta?.thumbnail_url,
                                thumbnailIsSquare: lastDownloadMeta?.thumbnail_is_square
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lastDownloadMeta?.title ?? "Now Playing")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                if let artist = lastDownloadMeta?.artist, !artist.isEmpty {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    ContentView()
}
