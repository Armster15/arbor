//
//  Models.swift
//  Arbor
//
//  Created by Armaan Aggarwal on 11/11/25.
//

import SwiftData

@Model
class LibraryItem {
    var id: UUID
    var original_url: String
    var title: String
    var artist: String
    var thumbnail_url: String?
    var thumbnail_width: Int?
    var thumbnail_height: Int?
    var thumbnail_is_square: Bool?
    var speedRate: Float
    var pitchCents: Float
    var reverbMix: Float
    
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
        self.id = UUID()
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
}
