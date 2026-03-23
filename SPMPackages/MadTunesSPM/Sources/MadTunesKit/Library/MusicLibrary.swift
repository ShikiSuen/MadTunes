// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import CoreGraphics
import Foundation
import ImageIO
import Observation
import SwiftData

// MARK: - ImportProgress

public struct ImportProgress {
  // MARK: Lifecycle

  public init(finishedCount: Int = 0, totalCount: Int = 0, fileName: String = "") {
    self.finishedCount = finishedCount
    self.totalCount = totalCount
    self.fileName = fileName
  }

  // MARK: Public

  public var finishedCount: Int = 0
  public var totalCount: Int = 0
  public var fileName: String = ""
}

// MARK: - MusicLibrary

/// Manages the music library: importing files, reading metadata, organising
/// tracks into albums, and maintaining playlists.
@Observable
@MainActor
public final class MusicLibrary {
  // MARK: Lifecycle

  // MARK: - Init

  nonisolated public init() {
    self._modelContainer = Self.makeModelContainer()
    // Phase 108: Create a dedicated SwiftData container for artwork caching.
    if let container = ArtworkCacheStore.makeContainer() {
      self._artworkCacheStore = ArtworkCacheStore(modelContainer: container)
    } else {
      self._artworkCacheStore = nil
    }
  }

  // MARK: Public

  // MARK: - Observable State

  public var tracks: [Track] = []
  public var albums: [Album] = []
  public var playlists: [Playlist] = [
    Playlist(
      name: String(localized: "i18n:Playlists.SystemLists.AllMusic", bundle: #bundle),
      kind: .system
    ),
    Playlist(
      name: String(localized: "i18n:Playlists.SystemLists.Favorites", bundle: #bundle),
      kind: .system
    ),
  ]
  public var isImporting: Bool = false
  public var artworkLoadingKeys: Set<String> = []

  public private(set) var importProgress = ImportProgress()
  public private(set) var hasLoadedPersistence = false

  /// Mutation token for observers.  Clients may track `library.$changeID` or
  /// use `withObservationTracking` to get callbacks when any noteworthy
  /// library update occurs (e.g. removal of tracks).
  public var changeID: UUID = .init()

  // MARK: - Artwork Cache (Phase 108: SwiftData-backed)

  /// Phase 108: Background actor for on-disk artwork cache.
  /// Replaces the former in-memory `artworkCache: [String: Data]` dictionary.
  public nonisolated let _artworkCacheStore: ArtworkCacheStore?

  // MARK: - Favorites

  /// 喜好項目播放清單（系統預設，不可刪除）
  public var favoritesPlaylist: Playlist {
    playlists[1]
  }

  // MARK: - Importing

  /// Import audio files (or directories) from an array of URLs.
  /// Duplicates (by file URL) are automatically skipped.
  /// Phase 99: Sequential metadata reading (replaced TaskGroup to avoid
  /// filesystem-level race conditions with concurrent file access).
  /// Phase 103: Returns the IDs of all imported tracks (including duplicates that
  /// were updated in-place). This allows callers to add them to playlists even
  /// when the files were previously imported.
  @discardableResult
  public func importFiles(urls: [URL]) async -> [UUID] {
    isImporting = true
    defer {
      currentProcessingFileName = ""
      importTotalFileCount = 0
      importFinishedFileCount = 0 // This action auto-updates `importProgress`.
      isImporting = false
    }

    // Phase 1: Collect all file URLs and grant security-scoped access.
    // Also persist bookmarks for user-selected source URLs.
    var allFileURLs: [URL] = []
    for url in urls {
      let accessGranted = url.startAccessingSecurityScopedResource()
      if accessGranted {
        activeSecurityScopedURLs.append(url)
      }
      // Persist a security-scoped bookmark for this user-selected source URL.
      persistSourceBookmark(for: url)

      var isDir: ObjCBool = false
      let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
      if exists, isDir.boolValue {
        allFileURLs.append(contentsOf: scanDirectory(url: url))
      } else if SupportedFormats.isSupported(url) {
        allFileURLs.append(url)
      }
    }

    // Phase 2: Read metadata sequentially (Phase 99: replaced TaskGroup).
    let batchSize = 50
    var existingURLs = Set(tracks.map(\.fileURL))
    var pendingTracks: [Track] = []
    importTotalFileCount = allFileURLs.count
    importFinishedFileCount = 0
    // Phase 103: Track all processed track IDs to return to caller (includes
    // both new tracks and existing tracks that were updated).
    var allProcessedTrackIDs: [UUID] = []

    for fileURL in allFileURLs {
      // Check if this is a Voice Memo before processing.
      let isVoice = await MetadataReader.isVoiceMemo(url: fileURL)
      if isVoice {
        importFinishedFileCount += 1
        continue
      }

      let meta = await MetadataReader.readTrackInfo(from: fileURL)
      var track = meta.track

      importFinishedFileCount += 1

      // Phase 79: Create per-file bookmark for sandbox persistence across app relaunches.
      if track.bookmarkData == nil {
        track.bookmarkData = Self.createBookmark(for: track.fileURL)
      }

      currentProcessingFileName = track.fileURL.lastPathComponent
      if existingURLs.contains(track.fileURL) {
        // Duplicate: update existing track’s metadata in-place.  Do **not** touch
        // `totalPlayCount` here – the user’s accumulated play count should survive
        // repeated imports.  The new `track` object has a fresh default count of 0,
        // so assigning `tracks[idx] = track` would reset the counter.
        if let idx = tracks.firstIndex(where: { $0.fileURL == track.fileURL }) {
          tracks[idx].title = track.title
          tracks[idx].artist = track.artist
          tracks[idx].albumTitle = track.albumTitle
          tracks[idx].albumArtist = track.albumArtist
          tracks[idx].trackNumber = track.trackNumber
          tracks[idx].discNumber = track.discNumber
          tracks[idx].duration = track.duration
          tracks[idx].genre = track.genre
          tracks[idx].year = track.year
          tracks[idx].fallbackFields = track.fallbackFields
          // totalPlayCount intentionally not modified
          // Phase 79: Backfill bookmark if previously missing.
          if tracks[idx].bookmarkData == nil {
            tracks[idx].bookmarkData = track.bookmarkData
          }
          // Phase 103: Record the existing track's ID (for playlist addition).
          allProcessedTrackIDs.append(tracks[idx].id)
        }
      } else {
        existingURLs.insert(track.fileURL)
        pendingTracks.append(track)
        // Phase 103: Record the new track's ID.
        allProcessedTrackIDs.append(track.id)
      }
      // Batch flush for progressive UI updates.
      if pendingTracks.count >= batchSize {
        tracks.append(contentsOf: pendingTracks)
        pendingTracks.removeAll(keepingCapacity: true)
        organizeAlbums()
      }
    }

    // Flush remaining tracks.
    var newTracksArray = tracks
    if !pendingTracks.isEmpty {
      newTracksArray.append(contentsOf: pendingTracks)
    }
    tracks = await newTracksArray.selfSortByDefault()
    if !playlists.isEmpty {
      playlists[0].trackIDs = tracks.map(\.id)
    }
    organizeAlbums()
    persistAllTracks()
    persistAllPlaylists()

    // Phase 103: Return the IDs of all processed tracks (new + existing).
    return allProcessedTrackIDs
  }

  // MARK: - Persistence

  /// Load persisted tracks from SwiftData. Call once at launch.
  /// Phase 102: Added deduplication check after loading tracks.
  public func loadPersistedData() async {
    guard !hasLoadedPersistence else { return }
    hasLoadedPersistence = true
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)

    // Step 1: Restore security-scoped access from source bookmarks.
    let sourceDescriptor = FetchDescriptor<PersistedSourceBookmark>()
    if let sourceBookmarks = try? context.fetch(sourceDescriptor) {
      for sb in sourceBookmarks {
        if let resolved = Self.resolveBookmark(sb.bookmarkData) {
          if resolved.startAccessingSecurityScopedResource() {
            activeSecurityScopedURLs.append(resolved)
          }
        }
      }
    }

    // Step 2: Load persisted tracks.
    let descriptor = FetchDescriptor<PersistedTrack>()
    guard let persisted = try? context.fetch(descriptor) else { return }
    var loadedTracks: [Track] = persisted.compactMap(\.asTrack)
    guard !loadedTracks.isEmpty else {
      // 即使沒有曲目，也要載入播放清單
      loadPersistedPlaylists()
      return
    }

    // Phase 102: Check for duplicates and deduplicate if needed.
    var (deduplicatedTracks, idMapping) = deduplicateTracks(loadedTracks)
    let needsDeduplication = !idMapping.isEmpty || deduplicatedTracks.count != loadedTracks.count

    if needsDeduplication {
      // Enter loading state to show cleanup progress UI.
      isImporting = true
      importProgress = ImportProgress(
        finishedCount: 0,
        totalCount: deduplicatedTracks.count,
        fileName: String(localized: "i18n:Import.CleanupDuplicates", bundle: #bundle)
      )

      // Apply deduplication: update tracks and remap playlist IDs.
      tracks = await deduplicatedTracks.selfSortByDefault()
      remapTrackIDsInPlaylists(idMapping: idMapping)

      // Reorganize albums with deduplicated tracks.
      organizeAlbums()

      // Persist the cleaned-up data back to database.
      persistAllTracks()
      persistAllPlaylists()

      // Exit loading state.
      isImporting = false
    } else {
      // No duplicates found: proceed normally.
      tracks = await loadedTracks.selfSortByDefault()
      if !playlists.isEmpty {
        playlists[0].trackIDs = tracks.map(\.id)
      }
      organizeAlbums()
    }

    loadPersistedPlaylists()
  }

  /// Clear all persisted data and in-memory state.
  public func clearDatabase() {
    // Stop all security-scoped access.
    for url in activeSecurityScopedURLs {
      url.stopAccessingSecurityScopedResource()
    }
    activeSecurityScopedURLs.removeAll()
    // Clear SwiftData.
    if let container = _modelContainer {
      let context = ModelContext(container)
      try? context.delete(model: PersistedTrack.self)
      try? context.delete(model: PersistedSourceBookmark.self)
      try? context.delete(model: PersistedPlaylist.self)
      try? context.save()
    }
    // Phase 108: Clear artwork SwiftData cache.
    Task { await _artworkCacheStore?.removeAll() }
    // Clear in-memory state.
    tracks.removeAll()
    albums.removeAll()
    artworkAttemptedKeys.removeAll()
    artworkLoadingContinuations.removeAll()
    albumIDMap.removeAll()
    if !playlists.isEmpty {
      playlists[0].trackIDs = []
    }
    if playlists.count > 1 {
      playlists[1].trackIDs = []
    }
    hasLoadedPersistence = false
  }

  // MARK: - Lazy Artwork Loading (Phase 108: SwiftData-backed)

  /// Phase 108: Load artwork for an album, returning cached data from SwiftData
  /// or loading from the audio file if not yet cached.
  /// Concurrent callers for the same key are coalesced — only one load runs,
  /// and all callers receive the same result.
  public func loadArtwork(
    forAlbumKey key: String,
    sampleTrackURL: URL,
    sampleTrackBookmark: Data?
  ) async
    -> ArtworkCacheResult? {
    // 1. Check SwiftData cache (fast path — background actor).
    if let cached = await _artworkCacheStore?.fetchArtwork(forKey: key) {
      return cached
    }

    // 2. If a load is already in progress, suspend and wait for it.
    if artworkLoadingKeys.contains(key) {
      return await withCheckedContinuation { continuation in
        artworkLoadingContinuations[key, default: []].append(continuation)
      }
    }

    // 3. If already attempted and not loading → definitively no artwork.
    if artworkAttemptedKeys.contains(key) {
      return nil
    }

    // 4. Start loading.
    artworkAttemptedKeys.insert(key)
    artworkLoadingKeys.insert(key)

    var trackURL = sampleTrackURL

    // Phase 80: resolve bookmark in sandbox environments.
    if !FileManager.default.isReadableFile(atPath: trackURL.path),
       let bookmark = sampleTrackBookmark,
       let resolved = Self.resolveBookmark(bookmark) {
      if resolved.startAccessingSecurityScopedResource() {
        activeSecurityScopedURLs.append(resolved)
        trackURL = resolved
      }
    }

    let rawData = await MetadataReader.readArtwork(from: trackURL)

    // Phase 92: Use dedicated ArtworkProcessor actor.
    var data = rawData
    if let raw = data {
      data = await ArtworkProcessor.shared.process(raw)
    }

    var result: ArtworkCacheResult?

    if let data {
      // Phase 108: Compute dominant color once and store alongside artwork.
      let hsb = ArtworkView.computeDominantHSB(from: data)

      await _artworkCacheStore?.store(
        imageData: data,
        dominantColorHue: hsb?.h,
        dominantColorSaturation: hsb?.s,
        dominantColorBrightness: hsb?.b,
        forKey: key
      )

      result = ArtworkCacheResult(
        data: data,
        dominantColorHue: hsb?.h,
        dominantColorSaturation: hsb?.s,
        dominantColorBrightness: hsb?.b
      )
    }

    // 5. Resume all suspended callers.
    artworkLoadingKeys.remove(key)
    if let waiters = artworkLoadingContinuations.removeValue(forKey: key) {
      for waiter in waiters {
        waiter.resume(returning: result)
      }
    }

    return result
  }

  // MARK: - Playlists

  public func addPlaylist(name: String) {
    playlists.append(Playlist(name: name, kind: .staticList))
    persistAllPlaylists()
  }

  public func removePlaylist(at index: Int) {
    // 只允許刪除非系統播放清單（index > 1，保留 All Music 和 Favorites）
    guard index > 1, index < playlists.count else { return }
    playlists.remove(at: index)
    persistAllPlaylists()
  }

  public func removePlaylist(id: UUID) {
    guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
    removePlaylist(at: index)
  }

  public func renamePlaylist(id: UUID, newName: String) {
    guard let index = playlists.firstIndex(where: { $0.id == id }),
          index > 1 else { return }
    playlists[index].name = newName
    persistAllPlaylists()
  }

  /// 從指定播放清單中移除曲目（不影響資料庫）。
  public func removeTracksFromPlaylist(_ trackIDs: Set<UUID>, playlistID: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    playlists[idx].trackIDs.removeAll { trackIDs.contains($0) }
    persistAllPlaylists()
  }

  /// 檢查指定曲目是否已加入喜好項目
  public func isFavorited(_ trackID: UUID) -> Bool {
    favoritesPlaylist.trackIDs.contains(trackID)
  }

  /// 切換指定曲目的喜好狀態。
  /// 若所有指定曲目皆已喜愛，則全部移除；否則將尚未喜愛的全部加入。
  public func toggleFavorite(trackIDs: Set<UUID>) {
    guard playlists.count > 1 else { return }
    var favorites = playlists[1]
    let existingSet = Set(favorites.trackIDs)
    let allFavorited = trackIDs.allSatisfy { existingSet.contains($0) }
    if allFavorited {
      favorites.trackIDs.removeAll { trackIDs.contains($0) }
    } else {
      let newIDs = trackIDs.filter { !existingSet.contains($0) }
      favorites.trackIDs.append(contentsOf: newIDs)
    }
    playlists[1] = favorites
    persistAllPlaylistsDebounced()
  }

  // MARK: - Track Management

  /// 將指定曲目加入指定播放清單（跳過已存在的）
  public func addTracks(_ trackIDs: Set<UUID>, toPlaylist playlistID: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    let existing = Set(playlists[idx].trackIDs)
    let newIDs = trackIDs.filter { !existing.contains($0) }
    playlists[idx].trackIDs.append(contentsOf: newIDs)
    persistAllPlaylistsDebounced()
  }

  /// 重新排序播放清單內的曲目（拖放功能）。
  ///
  /// - Parameters:
  ///   - trackIDs: 欲移動的曲目 ID（若為空則無操作）。
  ///   - playlistID: 目標播放清單 ID。
  ///   - toIndex: 希望插入到的索引位置（針對移除掉同樣曲目後的結果）。
  public func moveTracks(_ trackIDs: [UUID], inPlaylist playlistID: UUID, toIndex: Int) {
    guard !trackIDs.isEmpty else { return }
    guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistID }) else { return }

    // Only allow reordering for Favorites (system playlist index 1) and user-defined static playlists.
    // Do not allow reordering for All Music or dynamic playlists.
    let playlist = playlists[playlistIndex]
    guard playlist.kind == .staticList
      || (playlist.kind == .system && playlistIndex == 1) else {
      return
    }

    let existingIDs = playlists[playlistIndex].trackIDs
    let dragSet = Set(trackIDs)
    let draggedIDsInOrder = existingIDs.filter { dragSet.contains($0) }
    guard !draggedIDsInOrder.isEmpty else { return }

    // Determine insertion index after removing the dragged items.
    let beforeDraggedCount = existingIDs.prefix(min(toIndex, existingIDs.count)).filter { dragSet.contains($0) }.count
    let insertionIndex = max(0, min(existingIDs.count - draggedIDsInOrder.count, toIndex - beforeDraggedCount))

    var newOrder = existingIDs.filter { !dragSet.contains($0) }
    newOrder.insert(contentsOf: draggedIDsInOrder, at: insertionIndex)

    playlists[playlistIndex].trackIDs = newOrder
    persistAllPlaylistsDebounced()
  }

  /// Phase 115: Replace a static playlist's trackIDs with a new ordered array (persistent sort).
  /// Only allowed for Favorites (system index 1) and user-defined static playlists.
  public func reorderPlaylistTracks(playlistID: UUID, newTrackIDs: [UUID]) {
    guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    let playlist = playlists[playlistIndex]
    guard playlist.kind == .staticList
      || (playlist.kind == .system && playlistIndex == 1)
    else {
      return
    }
    playlists[playlistIndex].trackIDs = newTrackIDs
    persistAllPlaylistsDebounced()
  }

  /// 從資料庫中移除指定曲目（包含 SwiftData 持久層），並從所有播放清單中清理其引用
  public func removeTracks(ids: Set<UUID>) {
    // bump observable token so anyone watching knows something changed
    changeID = UUID()

    // 從曲目列表移除
    tracks.removeAll { ids.contains($0.id) }
    // 從所有播放清單中移除引用
    for i in playlists.indices {
      playlists[i].trackIDs.removeAll { ids.contains($0) }
    }
    organizeAlbums()
    persistAllTracks()
    persistAllPlaylists()
  }

  public func tracks(for playlist: Playlist) -> [Track] {
    // Preserve the order defined by the playlist (trackIDs array).
    // This allows playlist-specific ordering (e.g. drag-reorder) to be reflected
    // in views that display a flat track list.
    let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
    return playlist.trackIDs.compactMap { trackMap[$0] }
  }

  /// Build an album list filtered to only the tracks in a given playlist.
  public func albums(for playlist: Playlist) -> [Album] {
    let playlistTracks = tracks(for: playlist)
    var map: [String: (title: String, artist: String, tracks: [Track])] = [:]

    for track in playlistTracks {
      let key = albumKey(title: track.albumTitle, artist: track.albumArtist)
      if map[key] != nil {
        map[key]!.tracks.append(track)
      } else {
        map[key] = (title: track.albumTitle, artist: track.albumArtist, tracks: [track])
      }
    }

    return map.map { key, value in
      let id = stableAlbumID(for: key)
      return Album(
        id: id,
        title: value.title,
        artist: value.artist,
        tracks: value.tracks
      )
    }.sorted {
      $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
    }
  }

  // MARK: - Helpers

  public func albumKey(title: String, artist: String) -> String {
    "\(title):::\(artist)"
  }

  // MARK: Private

  // MARK: - Artwork Cache State

  /// Phase 108: Continuations for callers waiting on an in-progress artwork load.
  private var artworkLoadingContinuations: [String: [CheckedContinuation<ArtworkCacheResult?, Never>]] = [:]

  private var albumIDMap: [String: UUID] = [:]
  private var artworkAttemptedKeys: Set<String> = []
  private var activeSecurityScopedURLs: [URL] = []
  nonisolated private let importProgressDebouncer: Debouncer = .init(delay: 1)
  nonisolated private let persistPlaylistsDebouncer: Debouncer = .init(delay: 0.1)
  nonisolated private let _modelContainer: ModelContainer?

  @ObservationIgnored private var currentProcessingFileName: String = ""
  @ObservationIgnored private var importTotalFileCount: Int = 0

  @ObservationIgnored private var importFinishedFileCount: Int = 0 {
    didSet {
      Task {
        await importProgressDebouncer.debounce(keepFirstAttemptInstead: true) { @MainActor in
          self.importProgress = .init(
            finishedCount: self.importFinishedFileCount,
            totalCount: self.importTotalFileCount,
            fileName: self.currentProcessingFileName
          )
        }
      }
    }
  }

  // MARK: - SwiftData Container

  private nonisolated static func makeModelContainer() -> ModelContainer? {
    let schema = Schema(PersistedSchemaV2.models)
    let config = ModelConfiguration(schema: schema)
    do {
      return try ModelContainer(
        for: schema,
        migrationPlan: PersistedSchemaMigrationPlan.self,
        configurations: [config]
      )
    } catch {
      // Database corrupted — delete and recreate.
      let url = config.url
      try? FileManager.default.removeItem(at: url)
      // Also clean up WAL/SHM sidecar files.
      let walURL = url.appendingPathExtension("wal")
      let shmURL = url.appendingPathExtension("shm")
      try? FileManager.default.removeItem(at: walURL)
      try? FileManager.default.removeItem(at: shmURL)
      return try? ModelContainer(
        for: schema,
        migrationPlan: PersistedSchemaMigrationPlan.self,
        configurations: [config]
      )
    }
  }

  private nonisolated static func resolveBookmark(_ data: Data) -> URL? {
    var stale = false
    #if os(macOS) || targetEnvironment(macCatalyst)
    return try? URL(
      resolvingBookmarkData: data,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    #else
    return try? URL(
      resolvingBookmarkData: data,
      options: [],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    #endif
  }

  private nonisolated static func createBookmark(for url: URL) -> Data? {
    #if os(macOS) || targetEnvironment(macCatalyst)
    do {
      return try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    } catch {
      print("[MusicLibrary] Bookmark creation error for \(url.lastPathComponent): \(error)")
      return nil
    }
    #else
    return try? url.bookmarkData()
    #endif
  }

  /// Persist all current tracks to SwiftData (incremental update).
  /// Phase 99: Replaced `context.enumerate` with `context.fetch` to avoid
  /// modifying the collection mid-enumeration and causing data inconsistencies.
  /// Phase 102: Added deduplication for "same URL, different UUID" and
  /// "same UUID, different URL" scenarios before persisting.
  private func persistAllTracks() {
    // Phase 102: Deduplicate tracks before persisting.
    // Handle "same URL, different UUID" - keep the first occurrence, remap others.
    // Handle "same UUID, different URL" - treat as new track (generate new UUID).
    let (deduplicatedTracks, idMapping) = deduplicateTracks(tracks)

    // Apply ID mapping to playlists if any duplicates were found.
    if !idMapping.isEmpty {
      remapTrackIDsInPlaylists(idMapping: idMapping)
      // Update in-memory tracks to reflect deduplication.
      tracks = deduplicatedTracks
    }

    guard let container = _modelContainer else { return }
    let trackMap: [UUID: Track] = Dictionary(uniqueKeysWithValues: deduplicatedTracks.map { ($0.id, $0) })
    var newTrackIDs = Set(trackMap.keys)
    let context = ModelContext(container)
    do {
      let descriptor = FetchDescriptor<PersistedTrack>()
      let existingRecords = try context.fetch(descriptor)
      for existing in existingRecords {
        if newTrackIDs.contains(existing.id), let track = trackMap[existing.id] {
          existing.inherit(track)
          newTrackIDs.remove(existing.id)
        } else {
          context.delete(existing)
        }
      }
      for id in newTrackIDs {
        guard let track = trackMap[id] else { continue }
        context.insert(PersistedTrack(from: track))
      }
      try context.save()
    } catch {
      return
    }
  }

  // MARK: - Track Deduplication (Phase 102)

  /// Deduplicates tracks by URL and UUID.
  /// - Returns: A tuple containing the deduplicated tracks and an ID mapping
  ///   (removed ID -> kept ID) for updating playlist references.
  private func deduplicateTracks(_ tracks: [Track]) -> (tracks: [Track], idMapping: [UUID: UUID]) {
    var urlToTrackMap: [URL: (track: Track, index: Int)] = [:]
    var idMapping: [UUID: UUID] = [:]
    var result: [Track] = []

    for track in tracks {
      // Normalize URL for comparison (standardized path, ignoring fragment/query differences).
      let normalizedURL = track.fileURL.standardizedFileURL.resolvingSymlinksInPath()

      if let existingEntry = urlToTrackMap[normalizedURL] {
        // Duplicate URL found: map this track's ID to the existing track's ID.
        idMapping[track.id] = existingEntry.track.id
        // Keep the track with more complete metadata (longer title/artist/album combined).
        let existingCompleteness = existingEntry.track.title.count + existingEntry.track.artist.count + existingEntry
          .track.albumTitle.count
        let newCompleteness = track.title.count + track.artist.count + track.albumTitle.count
        if newCompleteness > existingCompleteness {
          // Replace with the more complete version, preserving the original ID.
          // Create a new track with the existing ID but new metadata.
          var replacementTrack = Track(
            id: existingEntry.track.id,
            fileURL: track.fileURL,
            title: track.title,
            artist: track.artist,
            albumTitle: track.albumTitle,
            albumArtist: track.albumArtist,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            duration: track.duration,
            genre: track.genre,
            year: track.year,
            fallbackFields: track.fallbackFields
          )
          replacementTrack.bookmarkData = track.bookmarkData
          result[existingEntry.index] = replacementTrack
          urlToTrackMap[normalizedURL] = (replacementTrack, existingEntry.index)
        }
      } else {
        // New unique URL: add to result.
        let index = result.count
        urlToTrackMap[normalizedURL] = (track, index)
        result.append(track)
      }
    }

    return (result, idMapping)
  }

  /// Updates all playlists to remap removed track IDs to their replacements.
  private func remapTrackIDsInPlaylists(idMapping: [UUID: UUID]) {
    for i in playlists.indices {
      var remappedIDs: [UUID] = []
      var seenIDs = Set<UUID>()

      for trackID in playlists[i].trackIDs {
        // Map to the kept ID if it was a duplicate, otherwise keep original.
        let finalID = idMapping[trackID] ?? trackID

        // Also deduplicate within the playlist itself.
        if !seenIDs.contains(finalID) {
          seenIDs.insert(finalID)
          remappedIDs.append(finalID)
        }
      }

      playlists[i].trackIDs = remappedIDs
    }
  }

  /// Persist all playlists to SwiftData (incremental update).
  /// Phase 99: Replaced `context.enumerate` with `context.fetch` to avoid
  /// modifying the collection mid-enumeration and causing data inconsistencies.
  private func persistAllPlaylists() {
    guard let container = _modelContainer else { return }
    let playlistMap: [UUID: (index: Int, playlist: Playlist)] = Dictionary(
      uniqueKeysWithValues: playlists.enumerated().map { ($1.id, ($0, $1)) }
    )
    var newPlaylistIDs = Set(playlistMap.keys)
    let context = ModelContext(container)
    do {
      let descriptor = FetchDescriptor<PersistedPlaylist>()
      let existingRecords = try context.fetch(descriptor)
      for existing in existingRecords {
        if newPlaylistIDs.contains(existing.id), let entry = playlistMap[existing.id] {
          existing.name = entry.playlist.name
          existing.trackIDs = entry.playlist.trackIDs
          existing.isSystemPlaylist = entry.playlist.isSystemPlaylist
          existing.sortIndex = entry.index
          existing.kindRawValue = entry.playlist.kind.rawValue
          newPlaylistIDs.remove(existing.id)
        } else {
          context.delete(existing)
        }
      }
      for id in newPlaylistIDs {
        guard let entry = playlistMap[id] else { continue }
        context.insert(PersistedPlaylist(
          id: entry.playlist.id,
          name: entry.playlist.name,
          trackIDs: entry.playlist.trackIDs,
          isSystemPlaylist: entry.playlist.isSystemPlaylist,
          sortIndex: entry.index,
          kindRawValue: entry.playlist.kind.rawValue
        ))
      }
      try context.save()
    } catch {
      return
    }
  }

  private func persistAllPlaylistsDebounced() {
    Task {
      await persistPlaylistsDebouncer.debounce(keepFirstAttemptInstead: true) { @MainActor in
        self.persistAllPlaylists()
      }
    }
  }

  /// Load persisted playlists from SwiftData.
  private func loadPersistedPlaylists() {
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<PersistedPlaylist>(sortBy: [SortDescriptor(\.sortIndex)])
    guard let persisted = try? context.fetch(descriptor) else { return }

    // 保留系統播放清單（All Music 和 Favorites），只載入使用者建立的播放清單
    var newPlaylists: [Playlist] = [
      Playlist(
        name: String(localized: "i18n:Playlists.SystemLists.AllMusic", bundle: #bundle),
        kind: .system
      ),
      Playlist(
        name: String(localized: "i18n:Playlists.SystemLists.Favorites", bundle: #bundle),
        kind: .system
      ),
    ]

    for persistedPlaylist in persisted {
      let playlist = persistedPlaylist.toPlaylist()
      // 只載入非系統播放清單，或名稱與系統播放清單匹配的（保留其 trackIDs）
      if playlist.isSystemPlaylist {
        // 更新系統播放清單的 trackIDs
        if let index = newPlaylists.firstIndex(where: { $0.name == playlist.name }) {
          newPlaylists[index].trackIDs = playlist.trackIDs
        }
      } else {
        newPlaylists.append(playlist)
      }
    }

    playlists = newPlaylists
    // 確保 All Music 包含所有曲目
    if !playlists.isEmpty {
      playlists[0].trackIDs = tracks.map(\.id)
    }
  }

  /// Persist a security-scoped bookmark for a user-selected source URL.
  private func persistSourceBookmark(for url: URL) {
    guard let container = _modelContainer else { return }
    guard let bookmarkData = Self.createBookmark(for: url) else {
      print("[MusicLibrary] WARNING: Failed to create source bookmark for: \(url.path)")
      return
    }
    let context = ModelContext(container)
    let urlString = url.absoluteString
    // Upsert: delete existing entry for same URL, then insert.
    let descriptor = FetchDescriptor<PersistedSourceBookmark>(
      predicate: #Predicate { $0.urlString == urlString }
    )
    if let existing = try? context.fetch(descriptor) {
      for e in existing { context.delete(e) }
    }
    context.insert(PersistedSourceBookmark(urlString: urlString, bookmarkData: bookmarkData))
    try? context.save()
  }

  // MARK: - Album Organisation

  private func organizeAlbums() {
    var map: [String: (title: String, artist: String, tracks: [Track])] = [:]

    for track in tracks {
      let key = albumKey(title: track.albumTitle, artist: track.albumArtist)
      if map[key] != nil {
        map[key]!.tracks.append(track)
      } else {
        map[key] = (title: track.albumTitle, artist: track.albumArtist, tracks: [track])
      }
    }

    albums = map.map { key, value in
      let id = stableAlbumID(for: key)
      return Album(
        id: id,
        title: value.title,
        artist: value.artist,
        tracks: value.tracks
      )
    }.sorted {
      $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
    }
  }

  private func stableAlbumID(for key: String) -> UUID {
    if let id = albumIDMap[key] { return id }
    let id = UUID()
    albumIDMap[key] = id
    return id
  }

  private func scanDirectory(url: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: [.isRegularFileKey],
      // Phase 101: Removed .skipsPackageDescendants to allow importing folders
      // with dots in their names (e.g., "My.Music.Folder") that may be
      // misidentified as packages by the system.
      options: [.skipsHiddenFiles]
    ) else { return [] }

    var results: [URL] = []
    for case let fileURL as URL in enumerator {
      let filename = fileURL.lastPathComponent
      guard !filename.hasPrefix(".") else { continue }
      if SupportedFormats.isSupported(fileURL) {
        results.append(fileURL)
      }
    }
    return results
  }
}
