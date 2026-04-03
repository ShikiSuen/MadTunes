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

  /// Phase 129: Tracks for folder playlists, keyed by playlist ID.
  /// These tracks are NOT in the main `tracks` array.
  public var folderPlaylistTracks: [UUID: [Track]] = [:]

  public private(set) var importProgress = ImportProgress()
  public private(set) var hasLoadedPersistence = false

  /// Phase 158: Sandbox bookmark health report, populated after loadPersistedData.
  public var sandboxHealthReport: SandboxHealthReport?

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
    evaluateAllDynamicPlaylists()

    // Phase 103: Return the IDs of all processed tracks (new + existing).
    return allProcessedTrackIDs
  }

  // MARK: - Reapprove Sandbox Privileges (Phase 164)

  /// Phase 164: Let the user re-grant sandbox access to a folder, then refresh
  /// stale bookmarks for any library tracks or folder-playlist folders whose
  /// paths fall under the selected folder.
  @discardableResult
  public func reapproveSandboxPrivileges(folderURL: URL) -> SandboxReapprovalReport {
    let accessGranted = folderURL.startAccessingSecurityScopedResource()
    if accessGranted {
      activeSecurityScopedURLs.append(folderURL)
    }
    // Persist a source bookmark so the access survives app relaunch.
    persistSourceBookmark(for: folderURL)

    let folderPath = Self.normalizedFolderPath(folderURL)
    // Ensure trailing "/" for safe prefix matching (avoids /Rock matching /Rockabilly).
    let folderPrefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
    var report = SandboxReapprovalReport()

    // Refresh per-file bookmarks for library tracks under the selected folder.
    for i in tracks.indices {
      let trackPath = tracks[i].fileURL.standardizedFileURL.resolvingSymlinksInPath().path
      guard trackPath.hasPrefix(folderPrefix) else { continue }
      report.checkedTrackCount += 1
      if let newBookmark = Self.createBookmark(for: tracks[i].fileURL) {
        tracks[i].bookmarkData = newBookmark
        report.refreshedTrackCount += 1
      }
    }

    // Refresh folder-playlist folder bookmarks under the selected folder.
    for i in playlists.indices where playlists[i].kind == .folderList {
      guard let fpURL = playlists[i].folderURL else { continue }
      let fpPath = Self.normalizedFolderPath(fpURL)
      guard fpPath.hasPrefix(folderPrefix) || fpPath == folderPath else { continue }
      report.checkedFolderPlaylistCount += 1
      if let newBookmark = Self.createBookmark(for: fpURL) {
        playlists[i].folderBookmarkData = newBookmark
        // Also update the persisted metadata.
        persistFolderPlaylistMetadata(
          playlistID: playlists[i].id,
          folderURL: fpURL,
          bookmarkData: newBookmark,
          trackIDs: folderPlaylistTracks[playlists[i].id]?.map(\.id) ?? []
        )
        report.refreshedFolderPlaylistCount += 1
      }
    }

    // Persist updated track bookmarks to SwiftData.
    if report.refreshedTrackCount > 0 {
      persistAllTracks()
    }

    // Clear any previous health report since the user just reapproved access.
    sandboxHealthReport = nil

    print(
      "[MusicLibrary] Reapproved sandbox: \(report.refreshedTrackCount) track(s), "
        + "\(report.refreshedFolderPlaylistCount) folder playlist(s) under \(folderPath)."
    )

    return report
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
    var report = SandboxHealthReport()
    let sourceDescriptor = FetchDescriptor<PersistedSourceBookmark>()
    if let sourceBookmarks = try? context.fetch(sourceDescriptor) {
      report.totalSourceBookmarks = sourceBookmarks.count
      for sb in sourceBookmarks {
        let (resolved, isStale) = Self.resolveBookmark(sb.bookmarkData)
        if let resolved {
          if resolved.startAccessingSecurityScopedResource() {
            activeSecurityScopedURLs.append(resolved)
          } else {
            report.failedSourceBookmarks += 1
          }
          // Phase 158: Auto-refresh stale bookmark.
          if isStale, let refreshed = Self.createBookmark(for: resolved) {
            sb.bookmarkData = refreshed
            try? context.save()
          }
        } else {
          report.failedSourceBookmarks += 1
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
      evaluateAllDynamicPlaylists()

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

    // Phase 129: Await folder playlist rescans so their tracks are available
    // for artwork cleanup (prevents incorrect purging of folder-exclusive artwork).
    await loadFolderPlaylistMetadataAsync(report: &report)

    // Phase 158: Publish health report.
    sandboxHealthReport = report.hasAnyFailure ? report : nil

    // Phase 129: Clean up orphaned artwork caches.
    await cleanupOrphanedArtworkCaches()
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
    folderPlaylistTracks.removeAll()
    folderPlaylistInitialReloadCheckedIDs.removeAll()
    folderPlaylistRescanInProgressIDs.removeAll()
    folderPlaylistLatestDirectoryModificationDates.removeAll()
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
    artworkLoadingKeys.insert(key)

    var trackURL = sampleTrackURL

    // Phase 80: resolve bookmark in sandbox environments.
    if !FileManager.default.isReadableFile(atPath: trackURL.path),
       let bookmark = sampleTrackBookmark {
      let (resolved, _) = Self.resolveBookmark(bookmark)
      if let resolved, resolved.startAccessingSecurityScopedResource() {
        activeSecurityScopedURLs.append(resolved)
        trackURL = resolved
      }
    }

    var rawData = await MetadataReader.readArtwork(from: trackURL)

    // Phase 130: If the sample track has no artwork, try other tracks in the
    // same album before giving up. Some albums have artwork embedded in only
    // certain tracks (e.g., different disc files, bonus tracks, etc.).
    if rawData == nil {
      let allCandidates = tracks + folderPlaylistTracks.values.flatMap { $0 }
      for candidate in allCandidates {
        let candidateKey = albumKey(title: candidate.albumTitle, artist: candidate.albumArtist)
        guard candidateKey == key, candidate.fileURL != trackURL else { continue }
        var candidateURL = candidate.fileURL
        if !FileManager.default.isReadableFile(atPath: candidateURL.path),
           let bm = candidate.bookmarkData {
          let (resolved, _) = Self.resolveBookmark(bm)
          if let resolved, resolved.startAccessingSecurityScopedResource() {
            activeSecurityScopedURLs.append(resolved)
            candidateURL = resolved
          }
        }
        let candidateData = await MetadataReader.readArtwork(from: candidateURL)
        if candidateData != nil {
          rawData = candidateData
          break
        }
      }
    }

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

    // 5. Mark as attempted only after loading completes (success or failure).
    // This allows retry if the first attempt failed due to transient issues
    // (sandbox access, file temporarily unreadable, etc.).
    artworkAttemptedKeys.insert(key)

    // 6. Resume all suspended callers.
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

  /// Phase 116: Create a dynamic playlist.
  public func addDynamicPlaylist(name: String) {
    playlists.append(Playlist(name: name, kind: .dynamicList))
    persistAllPlaylists()
  }

  // MARK: - Folder Playlists (Phase 129)

  /// Phase 129: Create a folder playlist and scan its contents.
  public func addFolderPlaylist(name: String, folderURL: URL) async {
    // Phase 132: If a folder playlist for the same path already exists,
    // do not create duplicates. Refresh existing content immediately.
    if let existingID = existingFolderPlaylistID(for: folderURL) {
      await rescanFolderPlaylist(id: existingID)
      return
    }

    let playlist = Playlist(name: name, kind: .folderList, folderURL: folderURL)

    let accessGranted = folderURL.startAccessingSecurityScopedResource()
    if accessGranted {
      activeSecurityScopedURLs.append(folderURL)
    }

    let bookmarkData = Self.createBookmark(for: folderURL) ?? Data()

    playlists.append(playlist)

    let scannedTracks = await scanFolderForTracks(folderURL)
    folderPlaylistTracks[playlist.id] = scannedTracks
    if let latestDate = Self.latestFolderTreeModificationDate(for: folderURL) {
      folderPlaylistLatestDirectoryModificationDates[playlist.id] = latestDate
    }

    // Phase 135 Post-Fix: Keep source-bound dynamic playlists in sync.
    // 實際上是 no-op（尚不可能有 dynamic playlist 引用它），但作為防禦性程式碼無害。
    reevaluateDynamicPlaylistsUsingSourceFolderPlaylist(playlist.id)

    persistFolderPlaylistMetadata(
      playlistID: playlist.id,
      folderURL: folderURL,
      bookmarkData: bookmarkData,
      trackIDs: scannedTracks.map(\.id)
    )
    persistAllPlaylists()
  }

  /// Phase 129: Rescan a folder playlist and update its cached tracks.
  public func rescanFolderPlaylist(id: UUID) async {
    guard folderPlaylistRescanInProgressIDs.insert(id).inserted else { return }
    defer { folderPlaylistRescanInProgressIDs.remove(id) }

    guard let index = playlists.firstIndex(where: { $0.id == id }),
          playlists[index].kind == .folderList else { return }

    let metadata = loadFolderPlaylistMetadata(for: id)
    guard let folderURL = resolvedFolderURL(for: id, metadata: metadata) else { return }

    // Check if we already have security-scoped access for this URL.
    let alreadyAccessing = activeSecurityScopedURLs.contains(folderURL)
    let accessGranted = alreadyAccessing || folderURL.startAccessingSecurityScopedResource()
    defer {
      // Only stop access if we started it in this call and it's not in the active list.
      if accessGranted, !alreadyAccessing, !activeSecurityScopedURLs.contains(folderURL) {
        folderURL.stopAccessingSecurityScopedResource()
      }
    }

    let scannedTracks = await scanFolderForTracks(folderURL)
    folderPlaylistTracks[id] = scannedTracks
    if let latestDate = Self.latestFolderTreeModificationDate(for: folderURL) {
      folderPlaylistLatestDirectoryModificationDates[id] = latestDate
    }

    // Phase 135 Post-Fix: Folder datasource updates must re-drive dependent
    // dynamic playlists; otherwise they can remain stuck with empty trackIDs.
    reevaluateDynamicPlaylistsUsingSourceFolderPlaylist(id)

    let refreshedBookmarkData = Self.createBookmark(for: folderURL)
    let bookmarkDataToPersist = refreshedBookmarkData ?? metadata?.folderBookmarkData ?? Data()

    persistFolderPlaylistMetadata(
      playlistID: id,
      folderURL: folderURL,
      bookmarkData: bookmarkDataToPersist,
      trackIDs: scannedTracks.map(\.id)
    )

    // Keep in-memory metadata consistent with the refreshed bookmark.
    playlists[index].folderURL = folderURL
    playlists[index].folderBookmarkData = bookmarkDataToPersist
  }

  /// Phase 129: Get tracks for a folder playlist.
  /// If cache is empty, triggers an async scan and returns empty array temporarily.
  public func tracksForFolderPlaylist(_ playlist: Playlist) -> [Track] {
    guard playlist.kind == .folderList else { return [] }

    // Phase 132: On first access after launch, lazily decide whether reload is needed.
    triggerLazyFolderPlaylistReloadCheckIfNeeded(playlistID: playlist.id)

    if let cached = folderPlaylistTracks[playlist.id], !cached.isEmpty {
      return cached
    }

    // Cache is empty - trigger async scan for next time.
    Task {
      await rescanFolderPlaylist(id: playlist.id)
    }

    return []
  }

  /// Phase 129: Import tracks from a folder playlist to main library and add to target playlist.
  public func importTracksFromFolderPlaylist(
    trackIDs: Set<UUID>,
    fromFolderPlaylist folderPlaylistID: UUID,
    toStaticPlaylist targetPlaylistID: UUID
  ) async {
    guard let folderTracks = folderPlaylistTracks[folderPlaylistID] else { return }
    let tracksToImport = folderTracks.filter { trackIDs.contains($0.id) }

    var importedTrackIDs: [UUID] = []
    let existingURLs = Set(tracks.map(\.fileURL))

    for track in tracksToImport {
      if existingURLs.contains(track.fileURL) {
        if let existing = tracks.first(where: { $0.fileURL == track.fileURL }) {
          importedTrackIDs.append(existing.id)
        }
      } else {
        // Phase 129 fix: Create per-file bookmark so the track survives app restart
        // even if the source folder playlist is later deleted.
        var importedTrack = track
        importedTrack.bookmarkData = Self.createBookmark(for: track.fileURL)
        tracks.append(importedTrack)
        importedTrackIDs.append(importedTrack.id)
      }
    }

    if !playlists.isEmpty {
      playlists[0].trackIDs = tracks.map(\.id)
    }

    addTracks(Set(importedTrackIDs), toPlaylist: targetPlaylistID)
    persistAllTracks()
  }

  /// Phase 129: Remove a folder playlist and its cached data.
  /// Phase 135: Also clear sourceFolderPlaylistIDSet references from dynamic playlists.
  public func removeFolderPlaylist(id: UUID) {
    guard let index = playlists.firstIndex(where: { $0.id == id }),
          playlists[index].kind == .folderList else { return }

    folderPlaylistTracks.removeValue(forKey: id)
    folderPlaylistInitialReloadCheckedIDs.remove(id)
    folderPlaylistRescanInProgressIDs.remove(id)
    folderPlaylistLatestDirectoryModificationDates.removeValue(forKey: id)
    purgePlaylistScopedAlbumIDs(playlistID: id)
    clearSourceFolderPlaylistReferences(for: id)
    playlists.remove(at: index)
    deleteFolderPlaylistMetadata(for: id)
    persistAllPlaylists()
  }

  public func removePlaylist(at index: Int) {
    // 只允許刪除非系統播放清單（index > 1，保留 All Music 和 Favorites）
    guard index > 1, index < playlists.count else { return }
    let removedID = playlists[index].id
    playlists.remove(at: index)
    purgePlaylistScopedAlbumIDs(playlistID: removedID)
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

  /// Phase 117: Move user playlists (index 2+) via drag-reorder.
  /// `fromOffsets` and `toOffset` are relative to the user-playlist sub-array (index 2+).
  public func moveUserPlaylists(fromOffsets source: IndexSet, toOffset destination: Int) {
    var userPlaylists = Array(playlists.dropFirst(2))
    userPlaylists.move(fromOffsets: source, toOffset: destination)
    playlists.replaceSubrange(2..., with: userPlaylists)
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

  /// Phase 116: Update a dynamic playlist's compound sort data (JSON-encoded).
  public func updateCompoundSortData(playlistID: UUID, data: Data) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    guard playlists[idx].kind == .dynamicList else { return }
    playlists[idx].compoundSortData = data
    persistAllPlaylistsDebounced()
  }

  /// Phase 117: Update a dynamic playlist's predicate data and re-evaluate.
  public func updatePredicateData(playlistID: UUID, data: Data) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    guard playlists[idx].kind == .dynamicList else { return }
    playlists[idx].predicateData = data
    evaluateDynamicPlaylist(at: idx)
    persistAllPlaylists()
  }

  /// Phase 135: Duplicate a playlist with a new UUID.
  /// Folder playlists (.folderList) and system playlists cannot be duplicated.
  /// Returns the ID of the newly created playlist, or nil if duplication failed.
  @discardableResult
  public func duplicatePlaylist(id: UUID) -> UUID? {
    guard let index = playlists.firstIndex(where: { $0.id == id }),
          index > 1 else { return nil }
    let source = playlists[index]
    guard source.kind != .folderList else { return nil }
    let duplicate = Playlist(duplicating: source)
    playlists.append(duplicate)
    persistAllPlaylists()
    return duplicate.id
  }

  /// Phase 135: Toggle a folder playlist in/out of a dynamic playlist's data source set.
  public func toggleSourceFolderPlaylist(playlistID: UUID, folderPlaylistID: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    guard playlists[idx].kind == .dynamicList else { return }
    guard let sourcePlaylist = playlists.first(where: { $0.id == folderPlaylistID }),
          sourcePlaylist.kind == .folderList else { return }
    if playlists[idx].sourceFolderPlaylistIDSet.contains(folderPlaylistID) {
      playlists[idx].sourceFolderPlaylistIDSet.remove(folderPlaylistID)
    } else {
      playlists[idx].sourceFolderPlaylistIDSet.insert(folderPlaylistID)
    }
    evaluateDynamicPlaylist(at: idx)
    persistAllPlaylists()
  }

  /// Phase 135: Clear all source folder playlist bindings (revert to full library).
  public func clearAllSourceFolderPlaylists(playlistID: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
    guard playlists[idx].kind == .dynamicList else { return }
    playlists[idx].sourceFolderPlaylistIDSet.removeAll()
    evaluateDynamicPlaylist(at: idx)
    persistAllPlaylists()
  }

  /// Phase 135: Get all folder playlists available as data sources.
  public func folderPlaylistsAsDataSources() -> [Playlist] {
    playlists.filter { $0.kind == .folderList }
  }

  /// Phase 117: Re-evaluate a dynamic playlist's predicate and update its trackIDs cache.
  public func evaluateDynamicPlaylist(id: UUID) {
    guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
    evaluateDynamicPlaylist(at: idx)
  }

  /// Phase 117: Re-evaluate all dynamic playlists (e.g. after track import/deletion).
  public func evaluateAllDynamicPlaylists() {
    for i in playlists.indices where playlists[i].kind == .dynamicList {
      evaluateDynamicPlaylist(at: i)
    }
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
    evaluateAllDynamicPlaylists()
  }

  public func tracks(for playlist: Playlist) -> [Track] {
    // Phase 129: Folder playlists have their own track storage.
    if playlist.kind == .folderList {
      return tracksForFolderPlaylist(playlist)
    }

    // Phase 135: Dynamic playlists bound to folder datasources use
    // folderPlaylistTracks IDs, which are independent from main library IDs.
    if playlist.kind == .dynamicList, !playlist.sourceFolderPlaylistIDSet.isEmpty {
      var sourceTrackMap: [UUID: Track] = [:]
      for sourceID in playlist.sourceFolderPlaylistIDSet {
        guard let sourcePlaylist = playlists.first(where: { $0.id == sourceID && $0.kind == .folderList })
        else { continue }
        for track in tracksForFolderPlaylist(sourcePlaylist) {
          sourceTrackMap[track.id] = track
        }
      }
      return playlist.trackIDs.compactMap { sourceTrackMap[$0] }
    }

    // Preserve the order defined by the playlist (trackIDs array).
    // This allows playlist-specific ordering (e.g. drag-reorder) to be reflected
    // in views that display a flat track list.
    let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
    return playlist.trackIDs.compactMap { trackMap[$0] }
  }

  /// Phase 133: Resolve the underlying folder URL for a folder playlist.
  /// Returns the bookmark-resolved URL when available, with metadata/playlist
  /// URL fallbacks for older records.
  public func folderURL(forFolderPlaylistID playlistID: UUID) -> URL? {
    guard let playlist = playlists.first(where: { $0.id == playlistID }),
          playlist.kind == .folderList else { return nil }
    return resolvedFolderURL(for: playlistID)
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
      // Phase 130 rev6: Playlist-scoped album IDs.
      // The same album key in different playlists must not share one UUID,
      // otherwise cross-playlist state/view identity can bleed.
      let scopedKey = playlistScopedAlbumKey(albumKey: key, playlistID: playlist.id)
      let id = stableAlbumID(for: scopedKey)
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
  @ObservationIgnored private var folderPlaylistInitialReloadCheckedIDs: Set<UUID> = []
  @ObservationIgnored private var folderPlaylistRescanInProgressIDs: Set<UUID> = []
  @ObservationIgnored private var folderPlaylistLatestDirectoryModificationDates: [UUID: Date] = [:]
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

  /// Phase 158: Returns (resolved URL, isStale) tuple.
  private nonisolated static func resolveBookmark(_ data: Data) -> (URL?, Bool) {
    #if os(macOS) && !targetEnvironment(macCatalyst)
    return resolveBookmark(data, options: .withSecurityScope)
    #elseif targetEnvironment(macCatalyst)
    // UIKit-based targets are less predictable with bookmark option handling,
    // so we try security-scoped resolution first, then tolerant fallbacks.
    let candidateOptions: [URL.BookmarkResolutionOptions] = [
      [.withSecurityScope, .withoutUI],
      .withSecurityScope,
      .withoutUI,
      [],
    ]
    for options in candidateOptions {
      let (resolved, isStale) = resolveBookmark(data, options: options)
      if resolved != nil {
        return (resolved, isStale)
      }
    }
    return (nil, false)
    #else
    return resolveBookmark(data, options: [])
    #endif
  }

  private nonisolated static func createBookmark(for url: URL) -> Data? {
    #if os(macOS) && !targetEnvironment(macCatalyst)
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
    #elseif targetEnvironment(macCatalyst)
    // Prefer security-scoped bookmarks, but keep fallbacks for UIKit targets.
    let candidateOptions: [URL.BookmarkCreationOptions] = [
      .withSecurityScope,
      .minimalBookmark,
      [],
    ]
    for options in candidateOptions {
      do {
        return try url.bookmarkData(
          options: options,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
      } catch {
        continue
      }
    }
    print("[MusicLibrary] Bookmark creation error for \(url.lastPathComponent): all option sets failed")
    return nil
    #else
    return try? url.bookmarkData()
    #endif
  }

  /// Phase 158: Returns (resolved URL, isStale) tuple.
  private nonisolated static func resolveBookmark(
    _ data: Data,
    options: URL.BookmarkResolutionOptions
  )
    -> (URL?, Bool) {
    var stale = false
    let url = try? URL(
      resolvingBookmarkData: data,
      options: options,
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    return (url, stale)
  }

  private nonisolated static func normalizedFolderPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  /// Phase 132: Returns the newest modification date among the folder
  /// and all its subfolders.
  private nonisolated static func latestFolderTreeModificationDate(for folderURL: URL) -> Date? {
    let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
    var latestDate = (try? folderURL.resourceValues(forKeys: resourceKeys))?.contentModificationDate

    guard let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: Array(resourceKeys),
      options: [.skipsHiddenFiles]
    ) else { return latestDate }

    for case let itemURL as URL in enumerator {
      let fileName = itemURL.lastPathComponent
      guard !fileName.hasPrefix(".") else { continue }
      guard let values = try? itemURL.resourceValues(forKeys: resourceKeys) else { continue }
      guard values.isDirectory == true,
            let modifiedDate = values.contentModificationDate else { continue }

      if let currentLatest = latestDate {
        if modifiedDate > currentLatest {
          latestDate = modifiedDate
        }
      } else {
        latestDate = modifiedDate
      }
    }

    return latestDate
  }

  private func playlistScopedAlbumKey(albumKey: String, playlistID: UUID) -> String {
    "playlist:\(playlistID.uuidString):::\(albumKey)"
  }

  /// Phase 135: Clear sourceFolderPlaylistIDSet references when a folder playlist is deleted.
  private func clearSourceFolderPlaylistReferences(for deletedID: UUID) {
    for i in playlists.indices where playlists[i].sourceFolderPlaylistIDSet.contains(deletedID) {
      playlists[i].sourceFolderPlaylistIDSet.remove(deletedID)
      if playlists[i].kind == .dynamicList {
        evaluateDynamicPlaylist(at: i)
      }
    }
  }

  /// Phase 135 Post-Fix: Re-evaluate dynamic playlists that depend on a folder
  /// playlist datasource after that folder's tracks are refreshed.
  private func reevaluateDynamicPlaylistsUsingSourceFolderPlaylist(_ sourcePlaylistID: UUID) {
    var hasDynamicPlaylistChanges = false
    for i in playlists.indices
      where playlists[i].kind == .dynamicList && playlists[i].sourceFolderPlaylistIDSet.contains(sourcePlaylistID) {
      evaluateDynamicPlaylist(at: i)
      hasDynamicPlaylistChanges = true
    }
    if hasDynamicPlaylistChanges {
      persistAllPlaylistsDebounced()
    }
  }

  /// Phase 129: Remove artwork cache entries that no longer have matching albums.
  /// Includes both main library and folder playlist tracks to avoid purging
  /// artwork that belongs exclusively to folder-playlist albums.
  private func cleanupOrphanedArtworkCaches() async {
    var allAlbumKeys = tracks.map { albumKey(title: $0.albumTitle, artist: $0.albumArtist) }
    for (_, folderTracks) in folderPlaylistTracks {
      allAlbumKeys.append(contentsOf: folderTracks.map { albumKey(title: $0.albumTitle, artist: $0.albumArtist) })
    }
    let activeAlbumKeys = Set(allAlbumKeys)
    await _artworkCacheStore?.cleanupOrphanedCaches(activeAlbumKeys: activeAlbumKeys)
  }

  // MARK: - Folder Playlist Helpers

  private func existingFolderPlaylistID(for folderURL: URL) -> UUID? {
    let candidatePath = Self.normalizedFolderPath(folderURL)

    for playlist in playlists where playlist.kind == .folderList {
      guard let existingURL = resolvedFolderURL(for: playlist.id) else { continue }
      if Self.normalizedFolderPath(existingURL) == candidatePath {
        return playlist.id
      }
    }

    return nil
  }

  private func triggerLazyFolderPlaylistReloadCheckIfNeeded(playlistID: UUID) {
    guard folderPlaylistInitialReloadCheckedIDs.insert(playlistID).inserted else { return }

    Task { @MainActor in
      if await shouldRescanFolderPlaylistOnFirstAccess(playlistID: playlistID) {
        await rescanFolderPlaylist(id: playlistID)
      }
    }
  }

  private func shouldRescanFolderPlaylistOnFirstAccess(playlistID: UUID) async -> Bool {
    guard let metadata = loadFolderPlaylistMetadata(for: playlistID),
          let folderURL = resolvedFolderURL(for: playlistID, metadata: metadata) else {
      return folderPlaylistTracks[playlistID]?.isEmpty ?? true
    }

    let latestDate = await Task.detached(priority: .utility) {
      Self.latestFolderTreeModificationDate(for: folderURL)
    }.value

    guard let latestDate else {
      return folderPlaylistTracks[playlistID]?.isEmpty ?? true
    }

    let baselineDate = folderPlaylistLatestDirectoryModificationDates[playlistID] ?? metadata.lastScannedAt
    folderPlaylistLatestDirectoryModificationDates[playlistID] = latestDate

    guard let baselineDate else { return true }
    return latestDate.timeIntervalSince(baselineDate) > 1
  }

  private func resolvedFolderURL(
    for playlistID: UUID,
    metadata: PersistedFolderPlaylistMetadata? = nil
  )
    -> URL? {
    let metadata = metadata ?? loadFolderPlaylistMetadata(for: playlistID)

    if let bookmarkData = metadata?.folderBookmarkData,
       !bookmarkData.isEmpty {
      let (resolvedURL, _) = Self.resolveBookmark(bookmarkData)
      if let resolvedURL { return resolvedURL }
    }

    if let folderURL = metadata?.folderURL {
      return folderURL
    }

    return playlists.first(where: { $0.id == playlistID })?.folderURL
  }

  private func scanFolderForTracks(_ folderURL: URL) async -> [Track] {
    let fileURLs = scanDirectory(url: folderURL).filter { SupportedFormats.isSupported($0) }
    var result: [Track] = []

    for fileURL in fileURLs {
      let metadata = await MetadataReader.readTrack(from: fileURL)
      result.append(metadata.track)
    }

    return await result.selfSortByDefault()
  }

  private func persistFolderPlaylistMetadata(
    playlistID: UUID,
    folderURL: URL,
    bookmarkData: Data,
    trackIDs: [UUID]
  ) {
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)

    let trackIDsData = (try? JSONEncoder().encode(trackIDs)) ?? Data()

    var descriptor = FetchDescriptor<PersistedFolderPlaylistMetadata>(
      predicate: #Predicate { $0.playlistID == playlistID }
    )
    descriptor.fetchLimit = 1

    if let existing = try? context.fetch(descriptor).first {
      existing.folderURLString = folderURL.absoluteString
      existing.folderBookmarkData = bookmarkData
      existing.cachedTrackIDsData = trackIDsData
      existing.lastScannedAt = Date()
    } else {
      let metadata = PersistedFolderPlaylistMetadata(
        playlistID: playlistID,
        folderURLString: folderURL.absoluteString,
        folderBookmarkData: bookmarkData,
        cachedTrackIDsData: trackIDsData,
        lastScannedAt: Date()
      )
      context.insert(metadata)
    }

    try? context.save()
  }

  private func loadFolderPlaylistMetadata(for playlistID: UUID) -> PersistedFolderPlaylistMetadata? {
    guard let container = _modelContainer else { return nil }
    let context = ModelContext(container)

    var descriptor = FetchDescriptor<PersistedFolderPlaylistMetadata>(
      predicate: #Predicate { $0.playlistID == playlistID }
    )
    descriptor.fetchLimit = 1

    return try? context.fetch(descriptor).first
  }

  private func deleteFolderPlaylistMetadata(for playlistID: UUID) {
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)

    var descriptor = FetchDescriptor<PersistedFolderPlaylistMetadata>(
      predicate: #Predicate { $0.playlistID == playlistID }
    )
    descriptor.fetchLimit = 1

    if let existing = try? context.fetch(descriptor).first {
      context.delete(existing)
      try? context.save()
    }
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

  /// Phase 117: Evaluate a dynamic playlist's predicate and update its trackIDs cache.
  /// Phase 135: Support sourceFolderPlaylistIDSet to limit evaluation to specific folder playlists.
  private func evaluateDynamicPlaylist(at index: Int) {
    guard playlists[index].kind == .dynamicList else { return }
    let data = playlists[index].predicateData
    guard !data.isEmpty,
          let predicate = try? JSONDecoder().decode(PlaylistPredicate.self, from: data)
    else {
      playlists[index].trackIDs = []
      return
    }

    let sourceTracks: [Track]
    let sourceIDs = playlists[index].sourceFolderPlaylistIDSet
    if !sourceIDs.isEmpty {
      var aggregated: [Track] = []
      for sourceID in sourceIDs {
        if let sourcePlaylist = playlists.first(where: { $0.id == sourceID && $0.kind == .folderList }) {
          aggregated.append(contentsOf: tracksForFolderPlaylist(sourcePlaylist))
        }
      }
      sourceTracks = aggregated
    } else {
      sourceTracks = tracks
    }

    playlists[index].trackIDs = predicate.filter(tracks: sourceTracks).map(\.id)
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
          existing.compoundSortData = entry.playlist.compoundSortData
          existing.predicateData = entry.playlist.predicateData
          existing.sourceFolderPlaylistIDs = Array(entry.playlist.sourceFolderPlaylistIDSet)
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
          kindRawValue: entry.playlist.kind.rawValue,
          compoundSortData: entry.playlist.compoundSortData,
          predicateData: entry.playlist.predicateData,
          sourceFolderPlaylistIDs: Array(entry.playlist.sourceFolderPlaylistIDSet)
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

    // Phase 117: Re-evaluate dynamic playlist caches on launch.
    // This guarantees playlists with empty/invalid predicateData are shown as empty,
    // and stale cached trackIDs from older versions are corrected.
    let previousDynamicTrackIDs = Dictionary(
      uniqueKeysWithValues: playlists
        .filter { $0.kind == .dynamicList }
        .map { ($0.id, $0.trackIDs) }
    )
    evaluateAllDynamicPlaylists()
    let currentDynamicTrackIDs = Dictionary(
      uniqueKeysWithValues: playlists
        .filter { $0.kind == .dynamicList }
        .map { ($0.id, $0.trackIDs) }
    )
    if previousDynamicTrackIDs != currentDynamicTrackIDs {
      persistAllPlaylists()
    }

    // Phase 129: Folder playlist metadata is loaded asynchronously via
    // loadFolderPlaylistMetadataAsync() in loadPersistedData() instead.
  }

  /// Phase 129: Load folder playlist metadata from SwiftData and await rescans.
  /// Awaiting rescans ensures folderPlaylistTracks is populated before artwork cleanup.
  private func loadFolderPlaylistMetadataAsync(report: inout SandboxHealthReport) async {
    guard let container = _modelContainer else { return }
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<PersistedFolderPlaylistMetadata>()
    guard let allMetadata = try? context.fetch(descriptor) else { return }

    report.totalFolderPlaylists = allMetadata.count

    for metadata in allMetadata {
      guard let playlist = playlists.first(where: { $0.id == metadata.playlistID }),
            playlist.kind == .folderList else { continue }

      // Restore folder URL and bookmark to Playlist struct.
      if let idx = playlists.firstIndex(where: { $0.id == metadata.playlistID }) {
        playlists[idx].folderURL = metadata.folderURL
        playlists[idx].folderBookmarkData = metadata.folderBookmarkData
      }

      // Restore security-scoped access.
      let folderURL: URL?
      if !metadata.folderBookmarkData.isEmpty {
        let (resolved, isStale) = Self.resolveBookmark(metadata.folderBookmarkData)
        if let resolved {
          folderURL = resolved
          // Phase 158: Auto-refresh stale bookmark.
          if isStale, let refreshed = Self.createBookmark(for: resolved) {
            metadata.folderBookmarkData = refreshed
            try? context.save()
          }
        } else {
          folderURL = nil
        }
      } else if let url = metadata.folderURL {
        folderURL = url
      } else {
        folderURL = nil
      }

      guard let folderURL else {
        // Phase 158: Track folder playlist failure.
        report.failedFolderPlaylists += 1
        report.failedFolderPlaylistIDs.insert(metadata.playlistID)
        continue
      }

      // Start accessing security-scoped resource.
      if folderURL.startAccessingSecurityScopedResource() {
        activeSecurityScopedURLs.append(folderURL)
      } else {
        // Phase 158: Security scope access denied.
        report.failedFolderPlaylists += 1
        report.failedFolderPlaylistIDs.insert(metadata.playlistID)
      }

      // Await rescan to ensure tracks are loaded before artwork cleanup.
      await rescanFolderPlaylist(id: metadata.playlistID)
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

  private func purgePlaylistScopedAlbumIDs(playlistID: UUID) {
    let prefix = "playlist:" + playlistID.uuidString + ":::"
    albumIDMap = albumIDMap.filter { !$0.key.hasPrefix(prefix) }
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
