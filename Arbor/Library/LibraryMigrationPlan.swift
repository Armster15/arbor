import Foundation
import SwiftData

enum ArborMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ArborSchemaV1.self, ArborSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: ArborSchemaV1.self,
                toVersion: ArborSchemaV2.self,
                willMigrate: { context in
                    let items = try context.fetch(FetchDescriptor<ArborSchemaV1.LibraryItem>())
                    for item in items {
                        let artists = splitArtists(from: item.artist)
                        let newItem = ArborSchemaV2.LibraryItem(
                            original_url: item.original_url,
                            title: item.title,
                            artists: artists,
                            thumbnail_url: item.thumbnail_url,
                            thumbnail_width: item.thumbnail_width,
                            thumbnail_height: item.thumbnail_height,
                            thumbnail_is_square: item.thumbnail_is_square,
                            speedRate: item.speedRate,
                            pitchCents: item.pitchCents,
                            reverbMix: item.reverbMix
                        )
                        newItem.id = item.id
                        newItem.createdAt = item.createdAt
                        context.insert(newItem)
                        context.delete(item)
                    }
                },
                didMigrate: nil
            )
        ]
    }
}

private func splitArtists(from artist: String) -> [String] {
    let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != "N/A" else { return [] }
    let parts = trimmed.split(separator: ",")
    let artists = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    return artists.filter { !$0.isEmpty }
}
