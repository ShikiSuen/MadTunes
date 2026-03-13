// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - TrackFieldFallbacks

public struct TrackFieldFallbacks: OptionSet, Sendable, Hashable {
  // MARK: Lifecycle

  public init(rawValue: Int) { self.rawValue = rawValue }

  // MARK: Public

  /// Title fell back to filename.
  public static let title = TrackFieldFallbacks(rawValue: 1 << 0)
  /// Artist fell back to composer, album artist, or "Unknown Artist".
  public static let artist = TrackFieldFallbacks(rawValue: 1 << 1)
  /// Album title fell back to track title or "Unknown Album".
  public static let albumTitle = TrackFieldFallbacks(rawValue: 1 << 2)
  /// Album artist fell back to (effective) artist.
  public static let albumArtist = TrackFieldFallbacks(rawValue: 1 << 3)

  public let rawValue: Int
}

// MARK: - Track

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
    year: Int? = nil,
    fallbackFields: TrackFieldFallbacks = []
  ) {
    self.id = id
    self.fileURL = fileURL
    self.folderPath = fileURL.deletingLastPathComponent().path
    self.title = title ?? fileURL.deletingPathExtension().lastPathComponent
    self.artist = artist
    self.albumTitle = albumTitle
    self.albumArtist = albumArtist.isEmpty ? artist : albumArtist
    self.trackNumber = trackNumber
    self.discNumber = discNumber
    self.duration = duration
    self.genre = genre
    self.year = year
    // Merge caller-provided fallback flags with init-level fallbacks.
    var fb = fallbackFields
    if title == nil { fb.insert(.title) }
    if albumArtist.isEmpty { fb.insert(.albumArtist) }
    self.fallbackFields = fb
  }

  // MARK: Public

  public let id: UUID
  public let fileURL: URL
  /// Pre-computed folder path for efficient sorting (avoids repeated URL operations).
  public let folderPath: String
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
  public var fallbackFields: TrackFieldFallbacks = []
}
