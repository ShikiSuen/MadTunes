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
    self.trackID = track.id.uuidString
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
  }

  // MARK: Internal

  @Attribute(.unique) var trackID: String
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

  func toTrack() -> Track? {
    guard let id = UUID(uuidString: trackID),
          let url = URL(string: fileURLString) else { return nil }
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
      year: year
    )
    track.bookmarkData = bookmarkData
    return track
  }
}
