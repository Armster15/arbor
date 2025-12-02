//
//  Models.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 11/11/25.
//

import SwiftData

@Model
class LibraryItem {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    // annoyingly, icloud sync'd models require all properties
    // to have default values or be optional.
    var original_url: String = "N/A"
    var title: String = "N/A"
    var artist: String = "N/A"
    var thumbnail_url: String?
    var thumbnail_width: Int?
    var thumbnail_height: Int?
    var thumbnail_is_square: Bool?
    var speedRate: Float = 1.0
    var pitchCents: Float = 0.0
    var reverbMix: Float = 0.0
    
    init(
        original_url: String,
        title: String,
        artist: String,
        thumbnail_url: String?,
        thumbnail_width: Int?,
        thumbnail_height: Int?,
        thumbnail_is_square: Bool?,
        speedRate: Float = 1.0,
        pitchCents: Float = 0.0,
        reverbMix: Float = 0.0
    ) {

        self.original_url = original_url
        self.title = title
        self.artist = artist
        self.thumbnail_url = thumbnail_url
        self.thumbnail_width = thumbnail_width
        self.thumbnail_height = thumbnail_height
        self.thumbnail_is_square = thumbnail_is_square
        self.speedRate = speedRate
        self.pitchCents = pitchCents
        self.reverbMix = reverbMix
    }
    
    convenience init(
        meta: DownloadMeta,
        speedRate: Float = 1.0,
        pitchCents: Float = 0.0,
        reverbMix: Float = 0.0
    ) {
        self.init(
            original_url: meta.original_url,
            title: meta.title,
            artist: meta.artist,
            thumbnail_url: meta.thumbnail_url,
            thumbnail_width: meta.thumbnail_width,
            thumbnail_height: meta.thumbnail_height,
            thumbnail_is_square: meta.thumbnail_is_square,
            speedRate: speedRate,
            pitchCents: pitchCents,
            reverbMix: reverbMix
        )
    }
    
    convenience init(copyOf item: LibraryItem) {
        self.init(
            original_url: item.original_url,
            title: item.title,
            artist: item.artist,
            thumbnail_url: item.thumbnail_url,
            thumbnail_width: item.thumbnail_width,
            thumbnail_height: item.thumbnail_height,
            thumbnail_is_square: item.thumbnail_is_square,
            speedRate: item.speedRate,
            pitchCents: item.pitchCents,
            reverbMix: item.reverbMix
        )
    }
}

// maps an original url (e.g. a youtube url) to a local file path
struct LibraryLocalFile: Codable {
    var id: UUID
    var createdAt: Date
    
    var originalUrl: String
    var filePath: String
        
    init(originalUrl: String, filePath: String) {
        self.id = UUID()
        self.createdAt = Date()
        
        self.originalUrl = originalUrl
        self.filePath = filePath
    }
}

func getLibraryLocalFile(originalUrl: String) -> LibraryLocalFile? {
    if let saved = UserDefaults.standard.object(forKey: "LibraryLocalFile:" + originalUrl) as? Data {
        let decoder = JSONDecoder()
        if let data = try? decoder.decode(LibraryLocalFile.self, from: saved) {
            return data
        }
    }
    
    return nil
}

func saveLibraryLocalFile(_ libraryLocalFile: LibraryLocalFile) {
    let encoder = JSONEncoder()
    let encoded = try! encoder.encode(libraryLocalFile)
    UserDefaults.standard.set(encoded, forKey: "LibraryLocalFile:" + libraryLocalFile.originalUrl)
}

func deleteLibraryLocalFile(originalUrl: String) {
    UserDefaults.standard.removeObject(forKey: "LibraryLocalFile:" + originalUrl)
}


struct DownloadMeta: Decodable {
    let path: String
    let original_url: String
    var title: String
    var artist: String
    let thumbnail_url: String?
    let thumbnail_width: Int?
    let thumbnail_height: Int?
    let thumbnail_is_square: Bool?
}

struct SearchResult: Decodable, Equatable {
    let title: String
    let artists: [String]
    let url: String
    let views: String?
    let duration: String?
    let isExplicit: Bool?
    let isVerified: Bool?
    let thumbnailURL: String?
    let thumbnailIsSquare: Bool?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case artists
        case url
        case views
        case duration
        case isExplicit = "is_explicit"
        case isVerified = "verified"
        case thumbnailURL = "thumbnail_url"
        case thumbnailIsSquare = "thumbnail_is_square"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
    }
}
