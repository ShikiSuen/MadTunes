// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import CoreGraphics
import Foundation
import ImageIO
import Observation
import SwiftData

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
  public var playlists: [Playlist] = [Playlist(name: "All Music")]
  public var isImporting: Bool = false
  public var currentProcessingFileName: String = ""
  public var importTotalFileCount: Int = 0
  public var importFinishedFileCount: Int = 0
  public var artworkLoadingKeys: Set<String> = []
  public private(set) var hasLoadedPersistence = false

  // MARK: - Importing

  /// Import audio files (or directories) from an array of URLs.
  /// Duplicates (by file URL) are automatically skipped.
  /// Uses TaskGroup for parallel metadata reading and batch UI updates.
  public func importFiles(urls: [URL]) async {
    isImporting = true
    defer {
      currentProcessingFileName = ""
      importTotalFileCount = 0
      importFinishedFileCount = 0
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

    await withTaskGroup(of: Track.self) { group in
      var iterator = allFileURLs.makeIterator()

      func enqueueNext() -> Bool {
        guard let fileURL = iterator.next() else { return false }
        group.addTask {
          let meta = await MetadataReader.readTrackInfo(from: fileURL)
          return meta.track
        }
        return true
      }

      // Seed initial tasks.
      for _ in 0 ..< maxConcurrency {
        if !enqueueNext() { break }
      }

      for await track in group {
        importFinishedFileCount += 1
        currentProcessingFileName = track.fileURL.lastPathComponent
        if !existingURLs.contains(track.fileURL) {
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

    // Flush remaining tracks.
    if !pendingTracks.isEmpty {
      tracks.append(contentsOf: pendingTracks)
    }
    if !playlists.isEmpty {
      playlists[0].trackIDs = tracks.map(\.id)
    }
    organizeAlbums()
    persistAllTracks()
  }

  // MARK: - Persistence

  /// Load persisted tracks from SwiftData. Call once at launch.
  public func loadPersistedData() {
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
    guard !loadedTracks.isEmpty else { return }
    tracks = loadedTracks
    if !playlists.isEmpty {
      playlists[0].trackIDs = tracks.map(\.id)
    }
    organizeAlbums()
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
    hasLoadedPersistence = false
  }

  // MARK: - Lazy Artwork Loading

  /// Request lazy artwork loading for an album. Called by views on appear.
  public func requestArtworkLoad(forAlbumKey key: String, sampleTrackURL: URL) {
    if artworkCache[key] != nil { return }
    if artworkAttemptedKeys.contains(key) { return }
    artworkAttemptedKeys.insert(key)
    artworkLoadingKeys.insert(key)
    Task {
      var data = await MetadataReader.readArtwork(from: sampleTrackURL)
      artworkLoadingKeys.remove(key)

      // Attempt to resize artwork to 512×512 px before caching
      if let raw = data {
        // Try standard instantiation first
        var processedData: Data?

        func resizeCGImage(_ cgImage: CGImage?) -> CGImage? {
          cgImage?.directResized(
            size: CGSize(width: 512, height: 512),
            preserveAspectRatio: true
          )
        }

        var useJPEGHint = false
        let cgImage: CGImage? = {
          let first = resizeCGImage(CGImage.instantiate(data: raw))
          if first != nil { return first }
          print("[MusicLibrary] Standard decode failed, retrying with JPEG hint...")
          useJPEGHint = true
          return resizeCGImage(CGImage.instantiate(data: raw, forceJPEG: true))
        }()

        if let resizedData = cgImage?.encodeToFileData(as: .jpeg(quality: 0.85)) {
          processedData = resizedData
          print("[MusicLibrary] \(useJPEGHint ? "JPEGHint" : "default") decode successful")
        } else {
          // If all decoding fails, keep original data as fallback
          print("[MusicLibrary] All decode attempts failed, using original data")
          processedData = raw
        }

        if let processedData {
          data = processedData
        }
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
    playlists.append(Playlist(name: name))
  }

  public func removePlaylist(at index: Int) {
    guard index > 0, index < playlists.count else { return }
    playlists.remove(at: index)
  }

  public func tracks(for playlist: Playlist) -> [Track] {
    let idSet = Set(playlist.trackIDs)
    return tracks.filter { idSet.contains($0.id) }
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

  // MARK: Internal

  // MARK: - Internal State

  var artworkCache: [String: Data] = [:]

  // MARK: Private

  // MARK: - Artwork Cache State

  /// Track deferred eviction to avoid race conditions with active display
  private var pendingDeferredEvictionTask: Task<Void, Never>?

  private var albumIDMap: [String: UUID] = [:]
  private var artworkCacheOrder: [String] = [] // FIFO order for LRU eviction
  private let artworkCacheCapacity = 50 // Limit to ~10MB (50 × 200KB avg)
  private var artworkAttemptedKeys: Set<String> = []
  private var activeSecurityScopedURLs: [URL] = []
  nonisolated private let _modelContainer: ModelContainer?

  // MARK: - SwiftData Container

  private nonisolated static func makeModelContainer() -> ModelContainer? {
    let schema = Schema([PersistedTrack.self, PersistedSourceBookmark.self])
    let config = ModelConfiguration(schema: schema)
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      // Database corrupted — delete and recreate.
      let url = config.url
      try? FileManager.default.removeItem(at: url)
      // Also clean up WAL/SHM sidecar files.
      let walURL = url.appendingPathExtension("wal")
      let shmURL = url.appendingPathExtension("shm")
      try? FileManager.default.removeItem(at: walURL)
      try? FileManager.default.removeItem(at: shmURL)
      return try? ModelContainer(for: schema, configurations: [config])
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

  /// Persist all current tracks to SwiftData (full replacement).
  private func persistAllTracks() {
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)
    // Clear existing track data and re-insert all tracks.
    do {
      try context.delete(model: PersistedTrack.self)
    } catch {
      return
    }
    for track in tracks {
      context.insert(PersistedTrack(from: track))
    }
    try? context.save()
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
