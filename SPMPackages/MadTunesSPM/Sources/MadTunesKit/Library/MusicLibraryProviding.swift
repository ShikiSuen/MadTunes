// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - MusicLibraryProviding

/// Protocol that abstracts MusicLibrary's data-access and mutation API.
/// ViewModels depend on this protocol rather than the concrete ``MusicLibrary``
/// class, enabling mock-based unit tests without SwiftData or filesystem access.
@MainActor
public protocol MusicLibraryProviding: AnyObject {
  // MARK: - Observable State (read)

  var tracks: [Track] { get set }
  var albums: [Album] { get set }
  var playlists: [Playlist] { get set }
  var isImporting: Bool { get }
  var hasLoadedPersistence: Bool { get }
  var changeID: UUID { get set }
  var artworkCache: [String: Data] { get }
  var artworkLoadingKeys: Set<String> { get }
  var importProgress: ImportProgress { get }
  var favoritesPlaylist: Playlist { get }

  // MARK: - Import

  func importFiles(urls: [URL]) async
  func loadPersistedData() async
  func clearDatabase()

  // MARK: - Lazy Artwork

  func requestArtworkLoad(forAlbumKey key: String, sampleTrackURL: URL)

  // MARK: - Playlist CRUD

  func addPlaylist(name: String)
  func removePlaylist(at index: Int)
  func removePlaylist(id: UUID)
  func renamePlaylist(id: UUID, newName: String)
  func removeTracksFromPlaylist(_ trackIDs: Set<UUID>, playlistID: UUID)

  // MARK: - Favorites

  func isFavorited(_ trackID: UUID) -> Bool
  func toggleFavorite(trackIDs: Set<UUID>)

  // MARK: - Track Management

  func addTracks(_ trackIDs: Set<UUID>, toPlaylist playlistID: UUID)
  func moveTracks(_ trackIDs: [UUID], inPlaylist playlistID: UUID, toIndex: Int)
  func removeTracks(ids: Set<UUID>)
  func tracks(for playlist: Playlist) -> [Track]
  func albums(for playlist: Playlist) -> [Album]

  // MARK: - Helpers

  func albumKey(title: String, artist: String) -> String
}

// MARK: - MusicLibrary + MusicLibraryProviding

extension MusicLibrary: MusicLibraryProviding {}
