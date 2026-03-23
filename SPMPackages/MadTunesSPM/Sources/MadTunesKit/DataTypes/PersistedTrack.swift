// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - PersistedTrack

@Model
final class PersistedTrack {
  // MARK: Lifecycle

  init(from track: Track) {
    self.id = track.id
    self.fileURLString = track.fileURL.absoluteString
    self.bookmarkData = track.bookmarkData
    self.title = track.title
    self.artist = track.artist
    self.albumTitle = track.albumTitle
    self.albumArtist = track.albumArtist
    self.trackNumber = track.trackNumber
    self.discNumber = track.discNumber
    self.duration = track.duration
    self.genre = track.genre
    self.year = track.year
    self.fallbackFieldsRawValue = track.fallbackFields.rawValue
  }

  // MARK: Internal

  // Note: 此處不宜將 fileURLString 標為 Unique。該專案已經有對應的重複排除機制了，所以不用擔心。

  @Attribute(.unique) var id: UUID
  var fileURLString: String
  var bookmarkData: Data?
  var title: String
  var artist: String
  var albumTitle: String
  var albumArtist: String
  var trackNumber: Int
  var discNumber: Int
  var duration: Double
  var genre: String
  var year: Int?
  var fallbackFieldsRawValue: Int = 0

  var asTrack: Track? {
    guard let url = URL(string: fileURLString) else { return nil }
    var track = Track(
      id: id,
      fileURL: url,
      title: title,
      artist: artist,
      albumTitle: albumTitle,
      albumArtist: albumArtist,
      trackNumber: trackNumber,
      discNumber: discNumber,
      duration: duration,
      genre: genre,
      year: year,
      fallbackFields: TrackFieldFallbacks(rawValue: fallbackFieldsRawValue)
    )
    track.bookmarkData = bookmarkData
    return track
  }

  func inherit(_ track: Track) {
    fileURLString = track.fileURL.absoluteString
    bookmarkData = track.bookmarkData
    title = track.title
    artist = track.artist
    albumTitle = track.albumTitle
    albumArtist = track.albumArtist
    trackNumber = track.trackNumber
    discNumber = track.discNumber
    duration = track.duration
    genre = track.genre
    year = track.year
    fallbackFieldsRawValue = track.fallbackFields.rawValue
  }
}
