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
    @Query var libraryItems: [LibraryItem]
    
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
                }
                .onDelete(perform: deleteLibraryItems)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Library")
    }
}
