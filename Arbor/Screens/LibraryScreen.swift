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
    
    func deleteLibraryItems(_ indexSet: IndexSet) {
        for index in indexSet {
            let model = libraryItems[index]
            modelContext.delete(model)
        }
    }
    
    func onTap(_ item: LibraryItem) {
        let localFile = getLibraryLocalFile(originalUrl: item.original_url)
        
        if let localFile = localFile {
            if !FileManager.default.fileExists(atPath: localFile.filePath) {
                deleteLibraryLocalFile(originalUrl: item.original_url)
                alertMessage = "No local file found for '\(item.title)'. Please download it first."
                showAlert = true
                return
            }
            
            player.startPlayback(libraryItem: item, filePath: localFile.filePath)
        } else {
            alertMessage = "No local file found for '\(item.title)'. Please download it first."
            showAlert = true
        }
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
    }
}
