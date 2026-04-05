// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
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
    tracks: [Track] = []
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    /// Tracks pre-sorted by (disc, track#, title). Computed once at init.
    self.tracks = tracks.sortedForAlbumContents()
    self.allTrackIDsSet = .init(tracks.map(\.id))
    // Phase 111: Cache year at init time to avoid O(n) per-comparison during sorting.
    self.year = self.tracks.compactMap(\.year).min()
  }

  /// Phase 111: Internal init accepting already-sorted tracks.
  /// Skips the sort step — use only when `tracks` are already in
  /// (disc, track#, title) order (e.g. filtered subsets of an existing album).
  init(
    id: UUID,
    title: String,
    artist: String,
    presortedTracks tracks: [Track]
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.tracks = tracks
    self.allTrackIDsSet = .init(tracks.map(\.id))
    self.year = tracks.compactMap(\.year).min()
  }

  // MARK: Public

  public let id: UUID
  public let title: String
  public let artist: String
  public let tracks: [Track]
  public let allTrackIDsSet: Set<UUID>

  /// Phase 111: Cached at init — the earliest year among the album's tracks, if available.
  public let year: Int?

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
}

// MARK: Hashable

extension Album: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(allTrackIDsSet)
  }

  public static func == (lhs: Album, rhs: Album) -> Bool {
    lhs.id == rhs.id && lhs.allTrackIDsSet == rhs.allTrackIDsSet
  }
}

// MARK: - AlbumSortOrder

public enum AlbumSortOrder: String, CaseIterable, Sendable {
  case artistYearTitle = "Artist › Year › Title"
  case artistTitleYear = "Artist › Title › Year"
  case yearArtistTitle = "Year › Artist › Title"

  // MARK: Internal

  var localizedName: String {
    switch self {
    case .artistYearTitle: String(localized: "i18n:AlbumSortMethod.ArtistYearTitle", bundle: #bundle)
    case .artistTitleYear: String(localized: "i18n:AlbumSortMethod.ArtistTitleYear", bundle: #bundle)
    case .yearArtistTitle: String(localized: "i18n:AlbumSortMethod.YearArtistTitle", bundle: #bundle)
    }
  }
}

// MARK: - SearchFilterMode

/// 搜尋過濾模式：決定搜尋文字要比對哪些欄位
public enum SearchFilterMode: String, CaseIterable, Sendable {
  case trackTitle = "Track Title"
  case albumTitle = "Album Title"
  case artist = "Artist & Album Artist"
  case either = "Either"

  // MARK: Internal

  var localizedName: String {
    switch self {
    case .trackTitle: String(localized: "i18n:SearchFilterMode.TrackTitle", bundle: #bundle)
    case .albumTitle: String(localized: "i18n:SearchFilterMode.AlbumTitle", bundle: #bundle)
    case .artist: String(localized: "i18n:SearchFilterMode.Artist", bundle: #bundle)
    case .either: String(localized: "i18n:SearchFilterMode.Either", bundle: #bundle)
    }
  }
}
