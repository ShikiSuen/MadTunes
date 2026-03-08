// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

public struct Track: Identifiable, Hashable, Sendable {
  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    fileURL: URL,
    title: String? = nil,
    artist: String = "Unknown Artist",
    albumTitle: String = "Unknown Album",
    albumArtist: String = "",
    trackNumber: Int = 0,
    discNumber: Int = 0,
    duration: TimeInterval = 0,
    genre: String = "",
    year: Int? = nil
  ) {
    self.id = id
    self.fileURL = fileURL
    self.title = title ?? fileURL.deletingPathExtension().lastPathComponent
    self.artist = artist
    self.albumTitle = albumTitle
    self.albumArtist = albumArtist.isEmpty ? artist : albumArtist
    self.trackNumber = trackNumber
    self.discNumber = discNumber
    self.duration = duration
    self.genre = genre
    self.year = year
  }

  // MARK: Public

  public let id: UUID
  public let fileURL: URL
  public var title: String
  public var artist: String
  public var albumTitle: String
  public var albumArtist: String
  public var trackNumber: Int
  public var discNumber: Int
  public var duration: TimeInterval
  public var genre: String
  public var year: Int?
  public var bookmarkData: Data?
}
