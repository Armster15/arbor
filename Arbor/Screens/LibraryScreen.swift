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
    
    var body: some View {
        Group {
            List {
                ForEach(libraryItems, id: \.persistentModelID) { item in
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.artist)
                            .font(.subheadline)
                        Text(item.id.uuidString)
                            .font(.caption)
                    }
                    .onTapGesture {
                        let originalUrl = item.original_url // required since you can't do item.original_url directly within the predicate
                        let fetchDescriptor = FetchDescriptor<LibraryLocalFile>(
                            predicate: #Predicate { $0.originalUrl == originalUrl }
                        )
                        
                        do {
                            let localFiles = try modelContext.fetch(fetchDescriptor)
                            if let localFile = localFiles.first {
                                // TODO: also check if the file still exists
                                player.startPlayback(libraryItem: item, filePath: localFile.filePath)
                            } else {
                                alertMessage = "No local file found for '\(item.title)'. Please download it first."
                                showAlert = true
                            }
                        } catch {
                            alertMessage = "Error loading file: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
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
