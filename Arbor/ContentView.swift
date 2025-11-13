//
//  ContentView.swift
//  pytest
//
//  Created by Armaan Aggarwal on 10/16/25.
//

import SwiftUI
import SwiftData
import UIKit

let BackgroundColor = LinearGradient(
    gradient: Gradient(colors: [
        Color("GradientStart"),
        Color("GradientEnd"),
    ]),
    startPoint: .top,
    endPoint: .bottom
)

struct ContentView: View {
    @EnvironmentObject var player: PlayerCoordinator
    
    init() {
        let titleColor = UIColor(named: "PrimaryText")!
        let normalTitleFont = UIFont(name: "Spicy Rice", size: 24)!
        let largeTitleFont = UIFont(name: "Spicy Rice", size: 32)!
        
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: titleColor, .font: normalTitleFont]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: titleColor, .font: largeTitleFont]
    }
    
    private enum Route: Hashable {
        case player
    }
    
    var body: some View {
        TabView {
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack() {
                    HomeScreen(
                        onDownloaded: { meta in
                            player.startPlayback(from: meta)
                        }
                    )
                    .background(BackgroundColor.ignoresSafeArea(.all)) // for root view
                }
            }

            Tab("Library", systemImage: "music.note.square.stack.fill") {
                NavigationStack() {
                    LibraryScreen()
                        .background(BackgroundColor.ignoresSafeArea(.all)) // for root view
                }
            }
        }
        .tabViewBottomAccessory {
            if let lastLibraryItem = player.lastLibraryItem, let audioPlayer = player.audioPlayer {
                HStack {
                    Button(action: { player.open() }) {
                        HStack(spacing: 12) {
                            SongImage(
                                width: 40,
                                height: 40,
                                thumbnailURL: lastLibraryItem.thumbnail_url,
                                thumbnailIsSquare: lastLibraryItem.thumbnail_is_square
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lastLibraryItem.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                Text(lastLibraryItem.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
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
        .sheet(isPresented: $player.isPresented) {
            if let audioPlayer = player.audioPlayer, let libraryItem = player.lastLibraryItem {
                NavigationStack {
                    ZStack {
                        BackgroundColor
                            .ignoresSafeArea()
                        
                        PlayerScreen(
                            libraryItem: libraryItem,
                            audioPlayer: audioPlayer
                        )
                    }
                }
                .id(ObjectIdentifier(ap))
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    @Previewable @StateObject var player = PlayerCoordinator()
    
    // dummy in-memory model container for preview environments
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LibraryItem.self, configurations: config)
    
    ContentView()
        .modelContainer(container)
        .environmentObject(player)
}
