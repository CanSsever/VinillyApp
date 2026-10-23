//
//  Vinyl.swift
//  VinillyApp
//
//  Final merged model
//

import Foundation
import SwiftData

@Model
final class Vinyl {
    @Attribute(.unique)
    var barcode: String

    var title: String
    var artist: String
    var genre: String
    var year: String

    // Kept for compatibility with the current UI.
    // DatabaseService maps v6.source_cover_url into this property.
    var coverUrl: String?

    var addedAt: Date = Date()

    // User-selected custom cover image.
    @Attribute(.externalStorage)
    var customImageData: Data?

    // Offline placeholder customization.
    var customColorHex: String?
    var customEmoji: String?

    init(
        barcode: String,
        title: String,
        artist: String,
        genre: String,
        year: String,
        coverUrl: String? = nil,
        addedAt: Date = Date(),
        customImageData: Data? = nil,
        customColorHex: String? = nil,
        customEmoji: String? = nil
    ) {
        self.barcode = barcode
        self.title = title
        self.artist = artist
        self.genre = genre
        self.year = year
        self.coverUrl = coverUrl
        self.addedAt = addedAt
        self.customImageData = customImageData
        self.customColorHex = customColorHex
        self.customEmoji = customEmoji
    }
}
