// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - PersistedSchemaV1

/// V1 schema: `PersistedTrack.trackID` and `PersistedPlaylist.playlistID` were
/// `String`-typed; playlist track references were `trackIDStrings: [String]`.
enum PersistedSchemaV1: VersionedSchema {
  @Model
  final class PersistedTrack {
    // MARK: Lifecycle

    init(
      trackID: String, fileURLString: String, bookmarkData: Data?,
      title: String, artist: String, albumTitle: String, albumArtist: String,
      trackNumber: Int, discNumber: Int, duration: Double,
      genre: String, year: Int?, fallbackFieldsRawValue: Int = 0
    ) {
      self.trackID = trackID
      self.fileURLString = fileURLString
      self.bookmarkData = bookmarkData
      self.title = title
      self.artist = artist
      self.albumTitle = albumTitle
      self.albumArtist = albumArtist
      self.trackNumber = trackNumber
      self.discNumber = discNumber
      self.duration = duration
      self.genre = genre
      self.year = year
      self.fallbackFieldsRawValue = fallbackFieldsRawValue
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
    var fallbackFieldsRawValue: Int = 0
  }

  @Model
  final class PersistedPlaylist {
    // MARK: Lifecycle

    init(
      playlistID: String, name: String, trackIDStrings: [String],
      isSystemPlaylist: Bool, sortIndex: Int, kindRawValue: String
    ) {
      self.playlistID = playlistID
      self.name = name
      self.trackIDStrings = trackIDStrings
      self.isSystemPlaylist = isSystemPlaylist
      self.sortIndex = sortIndex
      self.kindRawValue = kindRawValue
    }

    // MARK: Internal

    @Attribute(.unique) var playlistID: String
    var name: String
    var trackIDStrings: [String]
    var isSystemPlaylist: Bool
    var sortIndex: Int
    var kindRawValue: String
  }

  static let versionIdentifier: Schema.Version = .init(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [PersistedTrack.self, PersistedPlaylist.self, PersistedSourceBookmark.self]
  }
}

// MARK: - PersistedSchemaV2

/// V2 schema: identifiers use native `UUID`; playlist track references are `[UUID]`.
enum PersistedSchemaV2: VersionedSchema {
  static let versionIdentifier: Schema.Version = .init(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [PersistedTrack.self, PersistedPlaylist.self, PersistedSourceBookmark.self]
  }
}

// MARK: - PersistedSchemaMigrationPlan

/// Migrates from V1 (String-based IDs) to V2 (native UUID IDs).
///
/// Uses a custom migration stage that snapshots V1 data in `willMigrate`,
/// lets SwiftData transform the schema, then re-inserts records as V2
/// models in `didMigrate`.
enum PersistedSchemaMigrationPlan: SchemaMigrationPlan {
  // MARK: Internal

  // MARK: - V1 → V2

  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: PersistedSchemaV1.self,
    toVersion: PersistedSchemaV2.self,
    willMigrate: { context in
      // Snapshot all V1 records before schema transformation.
      let v1Tracks = try context.fetch(FetchDescriptor<PersistedSchemaV1.PersistedTrack>())
      _trackSnapshots = v1Tracks.map { t in
        TrackSnapshot(
          trackID: t.trackID, fileURLString: t.fileURLString,
          bookmarkData: t.bookmarkData, title: t.title,
          artist: t.artist, albumTitle: t.albumTitle,
          albumArtist: t.albumArtist, trackNumber: t.trackNumber,
          discNumber: t.discNumber, duration: t.duration,
          genre: t.genre, year: t.year,
          fallbackFieldsRawValue: t.fallbackFieldsRawValue
        )
      }
      for track in v1Tracks { context.delete(track) }

      let v1Playlists = try context.fetch(FetchDescriptor<PersistedSchemaV1.PersistedPlaylist>())
      _playlistSnapshots = v1Playlists.map { p in
        PlaylistSnapshot(
          playlistID: p.playlistID, name: p.name,
          trackIDStrings: p.trackIDStrings,
          isSystemPlaylist: p.isSystemPlaylist,
          sortIndex: p.sortIndex, kindRawValue: p.kindRawValue
        )
      }
      for playlist in v1Playlists { context.delete(playlist) }

      try context.save()
    },
    didMigrate: { context in
      // Re-insert V1 data as V2 records with native UUID identifiers.
      if let trackSnapshots = _trackSnapshots {
        for snap in trackSnapshots {
          guard let uuid = UUID(uuidString: snap.trackID) else { continue }
          context.insert(PersistedTrack(
            id: uuid, fileURLString: snap.fileURLString,
            bookmarkData: snap.bookmarkData, title: snap.title,
            artist: snap.artist, albumTitle: snap.albumTitle,
            albumArtist: snap.albumArtist, trackNumber: snap.trackNumber,
            discNumber: snap.discNumber, duration: snap.duration,
            genre: snap.genre, year: snap.year,
            fallbackFieldsRawValue: snap.fallbackFieldsRawValue
          ))
        }
        _trackSnapshots = nil
      }

      if let playlistSnapshots = _playlistSnapshots {
        for snap in playlistSnapshots {
          guard let uuid = UUID(uuidString: snap.playlistID) else { continue }
          context.insert(PersistedPlaylist(
            id: uuid, name: snap.name,
            trackIDs: snap.trackIDStrings.compactMap { UUID(uuidString: $0) },
            isSystemPlaylist: snap.isSystemPlaylist,
            sortIndex: snap.sortIndex, kindRawValue: snap.kindRawValue
          ))
        }
        _playlistSnapshots = nil
      }

      try context.save()
    }
  )

  static var schemas: [any VersionedSchema.Type] {
    [PersistedSchemaV1.self, PersistedSchemaV2.self]
  }

  static var stages: [MigrationStage] {
    [migrateV1toV2]
  }

  // MARK: Private

  private struct TrackSnapshot {
    let trackID: String
    let fileURLString: String
    let bookmarkData: Data?
    let title: String
    let artist: String
    let albumTitle: String
    let albumArtist: String
    let trackNumber: Int
    let discNumber: Int
    let duration: Double
    let genre: String
    let year: Int?
    let fallbackFieldsRawValue: Int
  }

  private struct PlaylistSnapshot {
    let playlistID: String
    let name: String
    let trackIDStrings: [String]
    let isSystemPlaylist: Bool
    let sortIndex: Int
    let kindRawValue: String
  }

  // MARK: - Bridge storage (willMigrate → didMigrate)

  nonisolated(unsafe) private static var _trackSnapshots: [TrackSnapshot]?
  nonisolated(unsafe) private static var _playlistSnapshots: [PlaylistSnapshot]?
}
