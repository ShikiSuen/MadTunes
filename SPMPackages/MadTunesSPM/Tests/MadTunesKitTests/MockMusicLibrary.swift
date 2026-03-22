// (c) 2026 and onwards Shiki Suen (AGPL-3.0-or-later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
@testable import MadTunesKit

// MARK: - MockMusicLibrary

/// Minimal in-memory stub conforming to ``MusicLibraryProviding``.
/// No SwiftData or file-system access — all state is held in plain arrays.
final class MockMusicLibrary: MusicLibraryProviding {
  // MARK: Internal

  // MARK: - Observable State

  var tracks: [Track] = []
  var albums: [Album] = []
  var playlists: [Playlist] = [
    Playlist(name: "All Music", kind: .system),
    Playlist(name: "♥ Favorites", kind: .system),
  ]
  var isImporting = false
  var hasLoadedPersistence = true
  var changeID = UUID()
  var artworkLoadingKeys: Set<String> = []
  var importProgress = ImportProgress()

  var favoritesPlaylist: Playlist {
    playlists.first(where: { $0.name == "♥ Favorites" }) ?? playlists[1]
  }

  // MARK: - Import (no-op for tests)

  func importFiles(urls _: [URL]) async -> [UUID] { [] }
  func loadPersistedData() async {}
  func clearDatabase() {
    tracks.removeAll()
    albums.removeAll()
  }

  // MARK: - Lazy Artwork (no-op)

  func loadArtwork(
    forAlbumKey _: String,
    sampleTrackURL _: URL,
    sampleTrackBookmark _: Data?
  ) async
    -> ArtworkCacheResult? { nil }

  // MARK: - Playlist CRUD

  func addPlaylist(name: String) {
    playlists.append(Playlist(name: name, kind: .staticList))
  }

  func removePlaylist(at index: Int) {
    guard playlists.indices.contains(index) else { return }
    playlists.remove(at: index)
  }

  func removePlaylist(id: UUID) {
    playlists.removeAll { $0.id == id }
  }

  func renamePlaylist(id: UUID, newName: String) {
    guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
    playlists[idx].name = newName
  }

  func removeTracksFromPlaylist(_ trackIDs: Set<UUID>, playlistID: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    playlists[idx].trackIDs.removeAll { trackIDs.contains($0) }
  }

  // MARK: - Favorites

  func isFavorited(_ trackID: UUID) -> Bool {
    favoriteTrackIDs.contains(trackID)
  }

  func toggleFavorite(trackIDs: Set<UUID>) {
    for id in trackIDs {
      if favoriteTrackIDs.contains(id) {
        favoriteTrackIDs.remove(id)
      } else {
        favoriteTrackIDs.insert(id)
      }
    }
  }

  // MARK: - Track Management

  func addTracks(_ trackIDs: Set<UUID>, toPlaylist playlistID: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    for id in trackIDs {
      if !playlists[idx].trackIDs.contains(id) {
        playlists[idx].trackIDs.append(id)
      }
    }
  }

  func moveTracks(_ trackIDs: [UUID], inPlaylist playlistID: UUID, toIndex: Int) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    let existingIDs = playlists[idx].trackIDs
    let dragSet = Set(trackIDs)
    let draggedIDsInOrder = existingIDs.filter { dragSet.contains($0) }
    guard !draggedIDsInOrder.isEmpty else { return }
    let beforeDraggedCount = existingIDs.prefix(min(toIndex, existingIDs.count))
      .filter { dragSet.contains($0) }.count
    let insertionIndex = max(0, min(existingIDs.count - draggedIDsInOrder.count, toIndex - beforeDraggedCount))
    var newOrder = existingIDs.filter { !dragSet.contains($0) }
    newOrder.insert(contentsOf: draggedIDsInOrder, at: insertionIndex)
    playlists[idx].trackIDs = newOrder
  }

  func removeTracks(ids: Set<UUID>) {
    tracks.removeAll { ids.contains($0.id) }
    albums = buildAlbums(from: tracks)
    for i in playlists.indices {
      playlists[i].trackIDs.removeAll { ids.contains($0) }
    }
  }

  func tracks(for playlist: Playlist) -> [Track] {
    let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
    return playlist.trackIDs.compactMap { trackMap[$0] }
  }

  func albums(for playlist: Playlist) -> [Album] {
    buildAlbums(from: tracks(for: playlist))
  }

  // MARK: - Helpers

  func albumKey(title: String, artist: String) -> String {
    "\(artist.lowercased())|\(title.lowercased())"
  }

  // MARK: - Test Helpers

  /// Convenience: add tracks and rebuild albums.
  func setTracks(_ newTracks: [Track]) {
    tracks = newTracks
    albums = buildAlbums(from: newTracks)
  }

  // MARK: Private

  private var favoriteTrackIDs: Set<UUID> = []

  private func buildAlbums(from trackList: [Track]) -> [Album] {
    Dictionary(grouping: trackList) { albumKey(title: $0.albumTitle, artist: $0.albumArtist) }
      .map { _, tracks in
        let first = tracks[0]
        return Album(title: first.albumTitle, artist: first.albumArtist, tracks: tracks)
      }
  }
}
