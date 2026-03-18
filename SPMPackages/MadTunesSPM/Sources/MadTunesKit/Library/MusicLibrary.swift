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

  // MARK: - Internal State

  public var artworkCache: [String: Data] = [:]

  // MARK: - Favorites

  /// 喜好項目播放清單（系統預設，不可刪除）
  public var favoritesPlaylist: Playlist {
    playlists[1]
  }

  // MARK: - Importing

  /// Import audio files (or directories) from an array of URLs.
  /// Duplicates (by file URL) are automatically skipped.
  /// Uses TaskGroup for parallel metadata reading and batch UI updates.
  public func importFiles(urls: [URL]) async {
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

    // Phase 2: Read metadata in parallel.
    let maxConcurrency = 8
    let batchSize = 50
    var existingURLs = Set(tracks.map(\.fileURL))
    var pendingTracks: [Track] = []
    importTotalFileCount = allFileURLs.count
    importFinishedFileCount = 0

    await withTaskGroup(of: Track?.self) { group in
      var iterator = allFileURLs.makeIterator()

      func enqueueNext() -> Bool {
        guard let fileURL = iterator.next() else { return false }
        group.addTask {
          // Check if this is a Voice Memo before processing
          let isVoice = await MetadataReader.isVoiceMemo(url: fileURL)
          if isVoice {
            print("[MusicLibrary] Skipping Voice Memo: \(fileURL.lastPathComponent)")
            return nil
          }

          let meta = await MetadataReader.readTrackInfo(from: fileURL)
          return meta.track
        }
        return true
      }

      // Seed initial tasks.
      for _ in 0 ..< maxConcurrency {
        if !enqueueNext() { break }
      }

      for await optionalTrack in group {
        importFinishedFileCount += 1
        // Skip voice memos (tracks that returned nil)
        guard var track = optionalTrack else { continue }

        // Phase 79: Create per-file bookmark for sandbox persistence across app relaunches.
        if track.bookmarkData == nil {
          track.bookmarkData = Self.createBookmark(for: track.fileURL)
        }

        currentProcessingFileName = track.fileURL.lastPathComponent
        if existingURLs.contains(track.fileURL) {
          // Duplicate: update existing track's metadata in-place.  Do **not** touch
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
          }
        } else {
          existingURLs.insert(track.fileURL)
          pendingTracks.append(track)
        }
        // Batch flush for progressive UI updates.
        if pendingTracks.count >= batchSize {
          tracks.append(contentsOf: pendingTracks)
          pendingTracks.removeAll(keepingCapacity: true)
          organizeAlbums()
        }
        _ = enqueueNext()
      }
    }

    // 之前的操作都是直接操縱 in-memory 資料庫。
    var newTracksArray = tracks
    // Flush remaining tracks.
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
  }

  // MARK: - Persistence

  /// Load persisted tracks from SwiftData. Call once at launch.
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
    var loadedTracks: [Track] = []
    for pt in persisted {
      guard let track = pt.toTrack() else { continue }
      loadedTracks.append(track)
    }
    guard !loadedTracks.isEmpty else {
      // 即使沒有曲目，也要載入播放清單
      loadPersistedPlaylists()
      return
    }
    tracks = await loadedTracks.selfSortByDefault()
    if !playlists.isEmpty {
      playlists[0].trackIDs = tracks.map(\.id)
    }
    organizeAlbums()
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
    // Clear in-memory state.
    tracks.removeAll()
    albums.removeAll()
    artworkCache.removeAll()
    artworkCacheOrder.removeAll()
    artworkAttemptedKeys.removeAll()
    albumIDMap.removeAll()
    if !playlists.isEmpty {
      playlists[0].trackIDs = []
    }
    if playlists.count > 1 {
      playlists[1].trackIDs = []
    }
    hasLoadedPersistence = false
  }

  // MARK: - Lazy Artwork Loading

  /// Request lazy artwork loading for an album. Called by views on appear.
  public func requestArtworkLoad(
    forAlbumKey key: String,
    sampleTrackURL: URL,
    sampleTrackBookmark: Data?
  ) {
    if artworkCache[key] != nil { return }
    if artworkAttemptedKeys.contains(key) { return }
    artworkAttemptedKeys.insert(key)
    artworkLoadingKeys.insert(key)
    Task {
      var trackURL = sampleTrackURL

      // Phase 80: In sandbox environments (e.g. iOS Simulator), the stored
      // file URL may not remain directly readable after relaunch. If the URL
      // is not readable, but we have a per-track bookmark, resolve it and
      // use the resolved URL to load artwork.
      if !FileManager.default.isReadableFile(atPath: trackURL.path),
         let bookmark = sampleTrackBookmark,
         let resolved = Self.resolveBookmark(bookmark) {
        if resolved.startAccessingSecurityScopedResource() {
          activeSecurityScopedURLs.append(resolved)
          trackURL = resolved
        }
      }

      var data = await MetadataReader.readArtwork(from: trackURL)
      artworkLoadingKeys.remove(key)

      // Phase 92: Use dedicated ArtworkProcessor actor instead of
      // per-request Task.detached, reducing thread-pool handoff overhead.
      if let raw = data {
        data = await ArtworkProcessor.shared.process(raw)
      }

      if let data {
        self.cacheArtwork(data, forKey: key)
      }

      // Update the corresponding Album in-place so views refresh.
      if let idx = self.albums.firstIndex(
        where: { self.albumKey(title: $0.title, artist: $0.artist) == key }
      ) {
        self.albums[idx].artworkData = data
      }
    }
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
        tracks: value.tracks,
        artworkData: artworkCache[key]
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

  /// Track deferred eviction to avoid race conditions with active display
  private var pendingDeferredEvictionTask: Task<Void, Never>?

  private var albumIDMap: [String: UUID] = [:]
  private var artworkCacheOrder: [String] = [] // FIFO order for LRU eviction
  private let artworkCacheCapacity = 50 // Limit to ~10MB (50 × 200KB avg)
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
  private func persistAllTracks() {
    guard let container = _modelContainer else { return }
    let trackMap: [UUID: Track] = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
    var newTrackIDs = Set(trackMap.keys)
    let context = ModelContext(container)
    do {
      let descriptor = FetchDescriptor<PersistedTrack>()
      try context.enumerate(descriptor) { existing in
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

  /// Persist all playlists to SwiftData (full replacement).
  private func persistAllPlaylists() {
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)
    // Clear existing playlist data and re-insert all playlists.
    do {
      try context.delete(model: PersistedPlaylist.self)
    } catch {
      return
    }
    for (index, playlist) in playlists.enumerated() {
      let persisted = PersistedPlaylist(
        playlistID: playlist.id.uuidString,
        name: playlist.name,
        trackIDStrings: playlist.trackIDs.map { $0.uuidString },
        isSystemPlaylist: playlist.isSystemPlaylist,
        sortIndex: index,
        kindRawValue: playlist.kind.rawValue
      )
      context.insert(persisted)
    }
    try? context.save()
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
        tracks: value.tracks,
        artworkData: artworkCache[key]
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

  // MARK: - LRU Artwork Cache Management

  /// Check if artwork for a given cache key is currently in active display use.
  /// Returns true if:
  /// - The key is in `artworkLoadingKeys` (currently loading/displaying), OR
  /// - An Album with this key has non-nil `artworkData` (visible in UI)
  private func isArtworkInUse(forKey key: String) -> Bool {
    // Check if currently loading
    if artworkLoadingKeys.contains(key) { return true }

    // Check if any album with this key has artwork data loaded in memory
    let albumKey = key
    if let albumIndex = albums.firstIndex(where: { albumKey == self.albumKey(title: $0.title, artist: $0.artist) }) {
      return albums[albumIndex].artworkData != nil
    }

    return false
  }

  /// Store artwork data in cache with deferred LRU eviction when capacity is exceeded.
  /// Capacity: 50 items (~10MB at 200KB per image)
  /// Eviction is deferred to avoid removing items while they're being displayed.
  private func cacheArtwork(_ data: Data, forKey key: String) {
    // If key already exists, remove it from order to re-add at the end (mark as recently used)
    if artworkCache[key] != nil {
      artworkCacheOrder.removeAll { $0 == key }
    }
    artworkCache[key] = data
    artworkCacheOrder.append(key)

    // Schedule deferred eviction instead of evicting immediately
    // This prevents removing items while views are still displaying them
    performDeferredEviction()
  }

  /// Perform deferred LRU eviction with visibility checking.
  /// Scheduled asynchronously to avoid concurrent display conflicts.
  private func performDeferredEviction() {
    // Cancel any pending eviction task to avoid queueing up multiple tasks
    pendingDeferredEvictionTask?.cancel()

    // Schedule eviction to run after a short delay (0.5 seconds)
    // This gives current display operations time to complete before eviction
    pendingDeferredEvictionTask = Task {
      // Wait before attempting eviction
      try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

      // Only proceed with eviction if not already cancelled
      guard !Task.isCancelled else { return }

      // Evict oldest items if capacity exceeded, but only if not in active use
      while artworkCache.count > artworkCacheCapacity {
        // Find the first item that is NOT in active use
        var evicted = false
        for i in 0 ..< artworkCacheOrder.count {
          let keyToCheck = artworkCacheOrder[i]
          if !isArtworkInUse(forKey: keyToCheck) {
            // Safe to evict: not currently loading or displaying
            artworkCache.removeValue(forKey: keyToCheck)
            artworkCacheOrder.remove(at: i)
            evicted = true
            break
          }
        }

        // If we couldn't find any item safe to evict, stop trying
        // This means all cached items are currently in use
        if !evicted { break }
      }
    }
  }

  private func scanDirectory(url: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
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
