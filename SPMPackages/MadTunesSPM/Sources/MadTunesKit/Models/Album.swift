// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - Album

public struct Album: Identifiable, Sendable {
  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    title: String,
    artist: String,
    tracks: [Track] = [],
    artworkData: Data? = nil
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.tracks = tracks
    self.allTrackIDsSet = .init(tracks.map(\.id))
    self.artworkData = artworkData
  }

  // MARK: Public

  public let id: UUID
  public let title: String
  public let artist: String
  public let tracks: [Track]
  public let allTrackIDsSet: Set<UUID>
  public var artworkData: Data?

  public var sortedTracks: [Track] {
    tracks.sorted {
      ($0.discNumber, $0.trackNumber, $0.title)
        < ($1.discNumber, $1.trackNumber, $1.title)
    }
  }

  public var totalDuration: TimeInterval {
    tracks.reduce(0) { $0 + $1.duration }
  }

  /// Whether every track's artist matches the album artist.
  /// When true, per-track artist display can be omitted.
  public var allTrackArtistsSameAsAlbumArtist: Bool {
    tracks.allSatisfy { $0.artist == artist }
  }

  /// Whether disc numbers should be shown in track listings.
  /// True only when there are multiple distinct disc numbers across the album's tracks.
  public var showDiscNumber: Bool {
    let distinct = Set(tracks.map(\.discNumber))
    return distinct.count > 1
  }

  /// The earliest year among the album's tracks, if available.
  public var year: Int? {
    tracks.compactMap(\.year).min()
  }
}

// MARK: Hashable

extension Album: Hashable {
  public func hash(into hasher: inout Hasher) { hasher.combine(id) }
  public static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
}

// MARK: - AlbumSortOrder

public enum AlbumSortOrder: String, CaseIterable, Sendable {
  case artistYearTitle = "Artist › Year › Title"
  case artistTitleYear = "Artist › Title › Year"
  case yearArtistTitle = "Year › Artist › Title"
}
