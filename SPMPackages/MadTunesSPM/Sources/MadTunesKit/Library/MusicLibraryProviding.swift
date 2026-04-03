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
  var artworkLoadingKeys: Set<String> { get }
  var importProgress: ImportProgress { get }
  var favoritesPlaylist: Playlist { get }
  /// Phase 158: Sandbox bookmark health report.
  var sandboxHealthReport: SandboxHealthReport? { get }

  // MARK: - Import

  func importFiles(urls: [URL]) async -> [UUID]
  func loadPersistedData() async
  func clearDatabase()

  // MARK: - Lazy Artwork

  /// Phase 108: Load artwork from SwiftData cache or audio file.
  func loadArtwork(
    forAlbumKey key: String,
    sampleTrackURL: URL,
    sampleTrackBookmark: Data?
  ) async -> ArtworkCacheResult?

  // MARK: - Playlist CRUD

  func addPlaylist(name: String)
  /// Phase 116: Create a dynamic playlist.
  func addDynamicPlaylist(name: String)
  /// Phase 129: Create a folder playlist.
  func addFolderPlaylist(name: String, folderURL: URL) async
  /// Phase 129: Rescan a folder playlist.
  func rescanFolderPlaylist(id: UUID) async
  /// Phase 129: Get tracks for a folder playlist.
  func tracksForFolderPlaylist(_ playlist: Playlist) -> [Track]
  /// Phase 129: Import tracks from folder playlist to main library.
  func importTracksFromFolderPlaylist(
    trackIDs: Set<UUID>,
    fromFolderPlaylist folderPlaylistID: UUID,
    toStaticPlaylist targetPlaylistID: UUID
  ) async
  /// Phase 129: Remove a folder playlist.
  func removeFolderPlaylist(id: UUID)
  func removePlaylist(at index: Int)
  func removePlaylist(id: UUID)
  func renamePlaylist(id: UUID, newName: String)
  /// Phase 117: Move user playlists (index 2+) via drag-reorder.
  func moveUserPlaylists(fromOffsets source: IndexSet, toOffset destination: Int)
  func removeTracksFromPlaylist(_ trackIDs: Set<UUID>, playlistID: UUID)

  // MARK: - Favorites

  func isFavorited(_ trackID: UUID) -> Bool
  func toggleFavorite(trackIDs: Set<UUID>)

  // MARK: - Track Management

  func addTracks(_ trackIDs: Set<UUID>, toPlaylist playlistID: UUID)
  func moveTracks(_ trackIDs: [UUID], inPlaylist playlistID: UUID, toIndex: Int)
  /// Phase 115: Replace a playlist’s trackIDs with a new ordered array (persistent sort).
  func reorderPlaylistTracks(playlistID: UUID, newTrackIDs: [UUID])
  /// Phase 116: Update compound sort data for a dynamic playlist.
  func updateCompoundSortData(playlistID: UUID, data: Data)
  /// Phase 117: Update predicate data for a dynamic playlist and re-evaluate.
  func updatePredicateData(playlistID: UUID, data: Data)
  /// Phase 117: Re-evaluate a single dynamic playlist's predicate.
  func evaluateDynamicPlaylist(id: UUID)
  /// Phase 117: Re-evaluate all dynamic playlists.
  func evaluateAllDynamicPlaylists()
  /// Phase 135: Update a dynamic playlist's source folder playlist ID.
  func toggleSourceFolderPlaylist(playlistID: UUID, folderPlaylistID: UUID)
  /// Phase 135: Clear all source folder playlist bindings (revert to full library).
  func clearAllSourceFolderPlaylists(playlistID: UUID)
  /// Phase 135: Get all folder playlists available as data sources.
  func folderPlaylistsAsDataSources() -> [Playlist]
  func removeTracks(ids: Set<UUID>)
  /// Phase 164: Re-grant sandbox access to a folder and refresh stale bookmarks.
  @discardableResult
  func reapproveSandboxPrivileges(folderURL: URL) -> SandboxReapprovalReport
  func tracks(for playlist: Playlist) -> [Track]
  func albums(for playlist: Playlist) -> [Album]

  // MARK: - Helpers

  func albumKey(title: String, artist: String) -> String
}

// MARK: - MusicLibrary + MusicLibraryProviding

extension MusicLibrary: MusicLibraryProviding {}
