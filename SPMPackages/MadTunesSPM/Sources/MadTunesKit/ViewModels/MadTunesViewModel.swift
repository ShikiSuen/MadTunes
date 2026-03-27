// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - MadTunesViewModel

@Observable
@MainActor
final class MadTunesViewModel {
  // MARK: Lifecycle

  init() {
    gridVM.mainVM = self
    tableVM.mainVM = self
    phoneVM.mainVM = self
    // Phase 96: Start ViewModel-level observations (replaces View .onChange blocks).
    setupObservations()
    phoneVM.setupObservations()
    gridVM.setupObservations()
    tableVM.setupObservations()
  }

  // MARK: Internal

  static let shared = MadTunesViewModel()

  let uiFactor: CGFloat = OS.isAppKit ? 1 : 1.3

  let modifierKeyMonitor = ModifierKeyMonitor.shared

  var library = MusicLibrary()
  var player = AudioPlayer()

  // Phase 60: Sub-ViewModels for table and grid views.
  var tableVM = AlbumTableViewModel()
  var gridVM = AlbumGridViewModel()

  // Phase 75: Sub-ViewModel for WP Metro-style phone UI.
  var phoneVM = WPPhoneViewModel()

  var selectedPlaylistID: UUID?
  var selectedTrackIDs: Set<UUID> = []
  /// Phase 127: Anchor for Shift+Arrow range selection in ExpandedAlbumView.
  var trackSelectionAnchorID: UUID?
  /// Phase 127: Cursor (moving end) for Shift+Arrow range selection in ExpandedAlbumView.
  var trackSelectionCursorID: UUID?
  var isFileImporterPresented = false // Only for non-AppKit targets.
  var isFolderImporterPresented = false // Also used on macOS AppKit as File Importer.
  var isDropTargeted = false
  var screenVM = ScreenVM.shared

  var searchFilterMode: SearchFilterMode = .either
  var isSearching: Bool = false

  /// Phase 121: Shared predicate editor state —
  /// lives here so iPad WPUI↔desktop switch preserves editing state.
  var predicateEditorVM: PredicateEditorViewModel?
  /// Phase 121: Playlist being edited; drives .sheet presentation at stable Scene level.
  var predicateEditorPlaylist: Playlist?

  // This property should stay in this mainVM since it is required by both view layouts.
  var displayedTracksCache: [Track] = []

  // Column Browser filter state (empty set = "All")
  var columnBrowserSelectedGenres: Set<String> = []
  /// Newly split from previous `Artists`; refers to the album-level artist.
  var columnBrowserSelectedAlbumArtists: Set<String> = []
  /// Separate song-artist filter (tracks' artist field).
  var columnBrowserSelectedSongArtists: Set<String> = []
  var columnBrowserSelectedAlbumTitles: Set<String> = []

  /// Phase 108: Stored artwork for the currently playing track.
  /// Loaded asynchronously from SwiftData when the current track changes.
  var currentTrackArtworkData: Image?
  /// Phase 108: Pre-computed dominant color for the current track's artwork.
  var currentTrackDominantColor: Color?

  var useTableView: Bool {
    get { access(keyPath: \.useTableView); return _useTableView }
    set { withMutation(keyPath: \.useTableView) { _useTableView = newValue } }
  }

  // Phase 63: SwiftUI-tracked modifier key state, replacing NSEvent.modifierFlags.

  var currentModifiers: EventModifiers {
    modifierKeyMonitor.currentModifiers
  }

  // Keyword search
  var searchText: String = "" {
    didSet {
      scheduleSearch()
    }
  }

  /// Whether any column browser filter is active.
  var isColumnBrowserFiltering: Bool {
    !columnBrowserSelectedGenres.isEmpty
      || !columnBrowserSelectedAlbumArtists.isEmpty
      || !columnBrowserSelectedSongArtists.isEmpty
      || !columnBrowserSelectedAlbumTitles.isEmpty
  }

  /// All unique genres from the currently visible playlist (before column browser filter).
  var columnBrowserGenres: [String] {
    let genres = Set(gridVM.unfilteredAlbums.flatMap { $0.tracks.map(\.genre) })
    return genres.filter { !$0.isEmpty }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Unique artists available given the current genre filter.
  /// Album–level artists available given current genre filter.
  var columnBrowserAlbumArtists: [String] {
    var source = gridVM.unfilteredAlbums
    if !columnBrowserSelectedGenres.isEmpty {
      source = source.filter { album in
        album.tracks.contains { columnBrowserSelectedGenres.contains($0.genre) }
      }
    }
    if !columnBrowserSelectedSongArtists.isEmpty {
      source = source.filter { album in
        album.tracks.contains { columnBrowserSelectedSongArtists.contains($0.artist) }
      }
    }
    let artists = Set(source.map(\.artist))
    return artists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Track-level artists (song artists) given current genre + album artist filters.
  var columnBrowserSongArtists: [String] {
    var source = gridVM.unfilteredAlbums
    if !columnBrowserSelectedGenres.isEmpty {
      source = source.filter { album in
        album.tracks.contains { columnBrowserSelectedGenres.contains($0.genre) }
      }
    }
    if !columnBrowserSelectedAlbumArtists.isEmpty {
      source = source.filter { columnBrowserSelectedAlbumArtists.contains($0.artist) }
    }
    // gather artists from tracks only
    let artists = Set(source.flatMap { $0.tracks.map(\.artist) })
    return artists.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Unique album titles available given the current genre + artist filter.
  var columnBrowserAlbumTitles: [String] {
    var source = gridVM.unfilteredAlbums
    if !columnBrowserSelectedGenres.isEmpty {
      source = source.filter { album in
        album.tracks.contains { columnBrowserSelectedGenres.contains($0.genre) }
      }
    }
    if !columnBrowserSelectedAlbumArtists.isEmpty {
      source = source.filter { columnBrowserSelectedAlbumArtists.contains($0.artist) }
    }
    if !columnBrowserSelectedSongArtists.isEmpty {
      source = source.filter { album in
        album.tracks.contains { columnBrowserSelectedSongArtists.contains($0.artist) }
      }
    }
    let titles = Set(source.map(\.title))
    return titles.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Single source of truth: all displayable tracks after applying all filters.
  /// Does NOT apply table sort — call `currentTracksDisplayed` for the sorted version.
  var filteredTracksBase: [Track] {
    let tokens = searchTokens(from: searchText)

    // When search is active and cache is ready, use cache (produced by async debounce).
    if !tokens.isEmpty, !displayedTracksCache.isEmpty || isSearching {
      return displayedTracksCache
    }

    let base = baseTracks
    // No filters at all → return as-is.
    if tokens.isEmpty, !isColumnBrowserFiltering { return base }

    return base.filter { trackPassesAllFilters($0, tokens: tokens, mode: searchFilterMode) }
  }

  /// Phase 130: When macOS provides both a file URL and its parent directory
  /// as separate drop items, remove the directory to prevent importing the
  /// entire folder when the user only dragged individual files.
  /// If no file-inside-directory overlap exists, all URLs pass through unchanged.
  static func deduplicateDroppedURLs(_ urls: [URL]) -> [URL] {
    guard urls.count > 1 else { return urls }
    var fileURLs: [URL] = []
    var dirURLs: [URL] = []
    for url in urls {
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
        dirURLs.append(url)
      } else {
        fileURLs.append(url)
      }
    }
    guard !dirURLs.isEmpty, !fileURLs.isEmpty else { return urls }
    // Remove any directory whose path is a prefix of at least one file URL.
    let filteredDirs = dirURLs.filter { dirURL in
      let dirPath = dirURL.standardizedFileURL.path
      let dirPrefix = dirPath.hasSuffix("/") ? dirPath : dirPath + "/"
      return !fileURLs.contains { $0.standardizedFileURL.path.hasPrefix(dirPrefix) }
    }
    return fileURLs + filteredDirs
  }

  func openPredicateEditor(for playlist: Playlist) {
    predicateEditorVM = PredicateEditorViewModel(playlist: playlist, library: library)
    predicateEditorPlaylist = playlist
  }

  // MARK: - Phase 58: Shared Per-Track Search Filter

  /// Shared per-track search filter following Phase 58 spec.
  /// Returns true if the track matches the given tokens under the specified mode.
  /// Reusable by ViewModel, ContextMenu, and ExpandedAlbumView.
  func trackMatchesSearch(_ track: Track, tokens: Set<String>, mode: SearchFilterMode) -> Bool {
    guard !tokens.isEmpty else { return true }
    switch mode {
    case .albumTitle:
      return tokensAllMatchAcrossFields(tokens, fields: [track.albumTitle])
    case .trackTitle:
      return tokensAllMatchAcrossFields(tokens, fields: [track.title])
    case .artist:
      return tokensAllMatchAcrossFields(tokens, fields: [track.albumArtist, track.artist])
    case .either:
      return tokensAllMatchAcrossFields(
        tokens,
        fields: [track.title, track.artist, track.albumTitle, track.albumArtist]
      )
    }
  }

  /// Returns true if a track passes both column browser AND search keyword filters.
  func trackPassesAllFilters(_ track: Track, tokens: Set<String>, mode: SearchFilterMode) -> Bool {
    if !columnBrowserSelectedGenres.isEmpty, !columnBrowserSelectedGenres.contains(track.genre) { return false }
    if !columnBrowserSelectedAlbumArtists.isEmpty,
       !columnBrowserSelectedAlbumArtists.contains(track.albumArtist) { return false }
    if !columnBrowserSelectedSongArtists.isEmpty,
       !columnBrowserSelectedSongArtists.contains(track.artist) { return false }
    if !columnBrowserSelectedAlbumTitles.isEmpty,
       !columnBrowserSelectedAlbumTitles.contains(track.albumTitle) { return false }
    return trackMatchesSearch(track, tokens: tokens, mode: mode)
  }

  // Phase 71: Purge stale entries from search caches after track removal.
  func invalidateSearchCacheForRemovedTracks(_ removedIDs: Set<UUID>) {
    guard !removedIDs.isEmpty else { return }
    if !displayedTracksCache.isEmpty {
      displayedTracksCache.removeAll { removedIDs.contains($0.id) }
    }
    if !gridVM.displayedAlbumsCache.isEmpty {
      gridVM.displayedAlbumsCache = gridVM.displayedAlbumsCache.compactMap { album in
        let remaining = album.tracks.filter { !removedIDs.contains($0.id) }
        guard !remaining.isEmpty else { return nil }
        return Album(
          id: album.id, title: album.title, artist: album.artist,
          tracks: remaining
        )
      }
    }
  }

  /// Phase 99: Explicitly push current data into both grid and table display
  /// buffers. This covers the `withObservationTracking` re-registration gap
  /// where mutations between onChange firing and Task re-registration are missed.
  func refreshDisplayBuffers() {
    gridVM.scheduleDisplayedAlbumsUpdate(to: gridVM.currentAlbumsDisplayed)
    tableVM.scheduleDisplayedTracksUpdate(to: tableVM.currentTracksDisplayed)
  }

  /// Removes tracks from the library and ensures they are also removed from
  /// playback state (queue/current track) and any cached filter results.
  /// Phase 86: Also cleans up cross-UI state (WPUI selection, recent album keys,
  /// expanded album, highlighted albums) to prevent stale references.
  func removeTracksFromLibrary(_ ids: Set<UUID>) async {
    guard !ids.isEmpty else { return }

    // If the currently playing track is being removed, stop playback.
    if let current = player.currentTrack, ids.contains(current.id) {
      await player.stop()
    }

    // Remove from the play queue (and adjust current index if needed).
    await player.removeFromQueue(trackIDs: ids)

    // Keep selection state consistent.
    selectedTrackIDs.subtract(ids)

    // Remove from library and all playlists.
    library.removeTracks(ids: ids)

    // Update caches used by various views.
    invalidateSearchCacheForRemovedTracks(ids)

    // Phase 86: Collapse expanded album if all its tracks were removed.
    if let expandedID = gridVM.expandedAlbumID,
       !library.albums.contains(where: { $0.id == expandedID }) {
      gridVM.expandedAlbumID = nil
    }

    // Phase 86: Purge deleted albums from Grid highlighted selection.
    let validAlbumIDs = Set(library.albums.map(\.id))
    if !gridVM.highlightedAlbumIDs.isEmpty {
      gridVM.highlightedAlbumIDs = gridVM.highlightedAlbumIDs.intersection(validAlbumIDs)
    }
    if let anchor = gridVM.albumSelectionFixedAnchorID, !validAlbumIDs.contains(anchor) {
      gridVM.albumSelectionFixedAnchorID = nil
    }
    if let cursor = gridVM.albumSelectionCursorID, !validAlbumIDs.contains(cursor) {
      gridVM.albumSelectionCursorID = nil
    }

    // Phase 86: Purge WPUI selection state referencing deleted albums.
    if !phoneVM.wpSelectedAlbumIDs.isEmpty {
      phoneVM.wpSelectedAlbumIDs = phoneVM.wpSelectedAlbumIDs.intersection(validAlbumIDs)
    }

    // Phase 86: Remove stale keys from recent album tracking.
    // Phase 97: recentAlbumKeys is @AppStorage; mutation auto-persists.
    let validAlbumKeys = Set(library.albums.map { library.albumKey(title: $0.title, artist: $0.artist) })
    phoneVM.recentAlbumKeys.removeAll { !validAlbumKeys.contains($0) }

    // Phase 86: Pop WPUI navigation if the user is viewing a now-deleted album or playlist.
    phoneVM.popNavigationIfDataInvalid(library: library)

    // Phase 99: Explicitly refresh display buffers to cover the
    // `withObservationTracking` re-registration gap where mutations
    // between onChange firing and Task re-registration are missed.
    refreshDisplayBuffers()
  }

  /// Resets column browser filters.
  func resetColumnBrowserFilters() {
    if !columnBrowserSelectedGenres.isEmpty { columnBrowserSelectedGenres = [] }
    if !columnBrowserSelectedAlbumArtists.isEmpty { columnBrowserSelectedAlbumArtists = [] }
    if !columnBrowserSelectedSongArtists.isEmpty { columnBrowserSelectedSongArtists = [] }
    if !columnBrowserSelectedAlbumTitles.isEmpty { columnBrowserSelectedAlbumTitles = [] }
  }

  /// Plays all tracks matching the current filter state.
  func playFilteredTracks() {
    let tracks = filteredTracksBase
    guard !tracks.isEmpty else { return }
    Task { await player.setQueue(tracks, startingAt: 0) }
  }

  func importURLs(_ urls: [URL]) {
    // Capture the playlist that was active when the import started.
    let targetPlaylistID = selectedPlaylistID
    Task {
      // Phase 103: importFiles returns IDs of all processed tracks (both new
      // and existing duplicates). This allows adding them to playlists even
      // when re-importing files that were previously imported.
      let importedTrackIDs = await library.importFiles(urls: urls)

      // After the import finishes, if the user was viewing anything other than
      // "All Music" we should also add the imported items to that playlist.
      // This covers the Favorites page (index 1) and any user-defined static
      // playlist. The operation is performed even if some of the files were
      // duplicates (the helper will simply skip entries that already exist in
      // the playlist).
      // Phase 103: Use the returned track IDs directly instead of path matching,
      // which failed when importing folders (folder path != file paths).
      // Phase 126: Skip adding to dynamic playlists (their content is rule-driven).
      // Phase 130: Also skip folder playlists (their content is folder-scan-driven).
      if let pid = targetPlaylistID,
         pid != library.playlists.first?.id,
         !importedTrackIDs.isEmpty {
        let playlistKind = library.playlists.first(where: { $0.id == pid })?.kind
        if playlistKind != .dynamicList, playlistKind != .folderList {
          library.addTracks(Set(importedTrackIDs), toPlaylist: pid)
        }
      }

      // Phase 99: Explicitly refresh display buffers after import completes.
      refreshDisplayBuffers()
    }
  }

  // MARK: - Drop Handling

  // Phase 100: Rewritten to (1) collect ALL URLs from all providers before
  // importing, preventing concurrent importFiles interleaving on MainActor;
  // (2) handle both file URLs and folder types; (3) handle both URL and Data
  // return types from NSItemProvider (Finder may return either).
  func handleDrop(_ providers: [NSItemProvider]) -> Bool {
    let relevantProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        || $0.hasItemConformingToTypeIdentifier(UTType.folder.identifier)
    }
    guard !relevantProviders.isEmpty else { return false }

    Task { @MainActor in
      var collectedURLs: [URL] = []
      for provider in relevantProviders {
        if let url = await self.extractDroppedURL(from: provider) {
          collectedURLs.append(url)
        }
      }
      guard !collectedURLs.isEmpty else { return }
      // Phase 130: macOS drag-and-drop may provide both a file URL and its
      // parent directory URL as separate providers. Deduplicate to prevent
      // importing the entire directory when the user only dragged a file.
      let deduplicatedURLs = Self.deduplicateDroppedURLs(collectedURLs)
      self.importURLs(deduplicatedURLs)
    }
    return true
  }

  // MARK: - Select All & Copy

  /// 選中所有肉眼可見的專輯（受 Column Browser 與搜尋篩選影響）
  func selectAllVisibleAlbums() {
    gridVM.highlightedAlbumIDs = Set(
      gridVM.currentAlbumsDisplayed.map(\.id)
    )
  }

  /// 獲取指定專輯中經過篩選的曲目。
  /// 使用共用的 `trackMatchesSearch` 做 per-track 篩選。
  /// 此函式在 ExpandedAlbumView、ContextMenu 等處皆可複用。
  func filteredTracks(for album: Album) -> [Track] {
    let tokens = searchTokens(from: searchText)
    guard !tokens.isEmpty else { return album.tracks }
    return album.tracks.filter { trackMatchesSearch($0, tokens: tokens, mode: searchFilterMode) }
  }

  /// 選中指定專輯中所有肉眼可見的曲目
  func selectAllVisibleTracks(in album: Album) {
    let tracks = filteredTracks(for: album)
    selectedTrackIDs = Set(tracks.map(\.id))
  }

  /// 複製選中曲目的中繼資料到剪貼簿
  func copySelectedTracksMetadata() {
    let tracks = selectedTrackIDs.compactMap { trackID in
      library.tracks.first { $0.id == trackID }
    }
    guard !tracks.isEmpty else { return }

    let tsv = tracksToTSV(tracks)
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(tsv, forType: .string)
    #else
    UIPasteboard.general.string = tsv
    #endif
  }

  /// Phase 96: Consolidated cleanup when switching playlists.
  func onPlaylistSwitched() {
    if !selectedTrackIDs.isEmpty { selectedTrackIDs.removeAll() }
    trackSelectionAnchorID = nil
    trackSelectionCursorID = nil
    gridVM.highlightedAlbumIDs.removeAll()
    gridVM.expandedAlbumID = nil
    gridVM.albumSelectionFixedAnchorID = nil
    gridVM.albumSelectionCursorID = nil
    tableVM.tableSelectionAnchorID = nil
    tableVM.tableSelectionCursorID = nil
    tableVM.isEditModeActive = false
    // Phase 115: Clear table sort so it doesn't leak across playlists.
    tableVM.clearTableSorting()
    // Phase 116: Restore persisted compound sort for the incoming dynamic playlist.
    tableVM.loadCompoundSortForCurrentPlaylist()
    resetColumnBrowserFilters()
    if !searchTokens(from: searchText).isEmpty {
      searchText = ""
    }
  }

  // MARK: Private

  /// When true the main content area shows AlbumTableView instead of AlbumGridView.
  /// Phase 97: Persisted via @AppStorage + @ObservationIgnored bridge.
  @ObservationIgnored @AppStorage("MadTunes.useTableView") private var _useTableView = false

  // MARK: - Phase 96: ViewModel-level Observations (replacing View .onChange blocks)

  /// Tracks the last known value of `selectedPlaylistID` for change detection.
  private var _previousSelectedPlaylistID: UUID?
  /// Tracks the last known value of `gridVM.expandedAlbumID` for change detection.
  private var _previousExpandedAlbumID: UUID?
  /// Tracks the last known value of `player.currentTrack?.id` for change detection.
  private var _previousCurrentTrackID: UUID?
  /// Tracks the last known value of `useTableView` for change detection.
  private var _previousUseTableView: Bool?

  // --- Async search/cache (Phase 57):
  // Cached filtered results produced by the debounced async search task.
  private var searchTask: Task<Void, Never>?

  // MARK: - Phase 58: New Data Pipeline (Single-Filter)

  /// Base tracks for the current playlist, before any filtering.
  /// Preserves playlist ordering for static/Favorites playlists.
  private var baseTracks: [Track] {
    if let playlistID = selectedPlaylistID,
       let playlist = library.playlists.first(where: { $0.id == playlistID }),
       playlist.id != library.playlists.first?.id {
      // Phase 129: Folder playlists use their own cached tracks.
      if playlist.kind == .folderList {
        return library.tracksForFolderPlaylist(playlist)
      }
      // Phase 117: Dynamic playlists use predicate-evaluated trackIDs cache.
      if playlist.kind == .dynamicList {
        return library.tracks(for: playlist)
      }
      return library.tracks(for: playlist)
    }
    return library.tracks
  }

  /// Extract a URL from a dropped NSItemProvider, handling both file URLs and
  /// folders, and both URL and Data return types.
  private func extractDroppedURL(from provider: NSItemProvider) async -> URL? {
    let typeIdentifier: String
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      typeIdentifier = UTType.fileURL.identifier
    } else if provider.hasItemConformingToTypeIdentifier(UTType.folder.identifier) {
      typeIdentifier = UTType.folder.identifier
    } else {
      return nil
    }

    return await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
        // Finder may return a URL directly (especially for folders) or Data.
        var rawURL: URL?
        if let url = item as? URL {
          rawURL = url
        } else if let data = item as? Data {
          rawURL = URL(dataRepresentation: data, relativeTo: nil)
        }

        guard let url = rawURL else {
          continuation.resume(returning: nil)
          return
        }

        #if os(macOS) || targetEnvironment(macCatalyst)
        if let bookmark = try? url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        ) {
          var stale = false
          if let scopedURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
          ) {
            _ = scopedURL.startAccessingSecurityScopedResource()
            continuation.resume(returning: scopedURL)
            return
          }
        }
        #endif
        continuation.resume(returning: url)
      }
    }
  }

  private func setupObservations() {
    observeUseTableViewChange()
    observeExpandedAlbumIDChange()
    observeSelectedPlaylistIDChange()
    observeCurrentTrackChange()
    observeUIModeSwitching()
    observePredicateEditorDismissal()
  }

  /// Phase 96: When `useTableView` changes, persist and clean up cross-view state.
  private func observeUseTableViewChange() {
    withObservationTracking {
      _ = self.useTableView
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        let newValue = self.useTableView
        let oldValue = self._previousUseTableView
        self._previousUseTableView = newValue
        if oldValue != nil, oldValue != newValue {
          self.tableVM.isEditModeActive = false
          if newValue {
            self.gridVM.expandedAlbumID = nil
            self.gridVM.highlightedAlbumIDs.removeAll()
            self.selectedTrackIDs.removeAll()
          }
        }
        self.observeUseTableViewChange()
      }
    }
    _previousUseTableView = useTableView
  }

  /// Phase 96: When `expandedAlbumID` changes, clear track selection.
  private func observeExpandedAlbumIDChange() {
    withObservationTracking {
      _ = self.gridVM.expandedAlbumID
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.selectedTrackIDs.removeAll()
        // Phase 127: Clear track selection anchor/cursor when expanded album changes.
        self.trackSelectionAnchorID = nil
        self.trackSelectionCursorID = nil
        self.observeExpandedAlbumIDChange()
      }
    }
  }

  /// Phase 96: When playlist is switched, reset selections, filters, and search.
  private func observeSelectedPlaylistIDChange() {
    withObservationTracking {
      _ = self.selectedPlaylistID
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        let newValue = self.selectedPlaylistID
        let oldValue = self._previousSelectedPlaylistID
        self._previousSelectedPlaylistID = newValue
        if oldValue != nil, oldValue != newValue {
          self.onPlaylistSwitched()
        } else if oldValue == nil, newValue != nil {
          // Phase 116: Initial playlist selection — load persisted compound sort.
          self.tableVM.loadCompoundSortForCurrentPlaylist()
        }
        self.observeSelectedPlaylistIDChange()
      }
    }
    _previousSelectedPlaylistID = selectedPlaylistID
  }

  /// Phase 96: When the current track changes, load artwork for it.
  /// Phase 108: Loads from SwiftData cache into stored properties.
  private func observeCurrentTrackChange() {
    withObservationTracking {
      _ = self.player.currentTrack?.id
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let track = self.player.currentTrack {
          let key = self.library.albumKey(title: track.albumTitle, artist: track.albumArtist)
          let result = await self.library.loadArtwork(
            forAlbumKey: key,
            sampleTrackURL: track.fileURL,
            sampleTrackBookmark: track.bookmarkData
          )
          if let imageData = result?.data, let cgImage = CGImage.instantiate(data: imageData) {
            self.currentTrackArtworkData = Image(decorative: cgImage, scale: 1)
          } else {
            self.currentTrackArtworkData = nil
          }
          if let h = result?.dominantColorHue,
             let s = result?.dominantColorSaturation,
             let b = result?.dominantColorBrightness {
            self.currentTrackDominantColor = Color(hue: h, saturation: s, brightness: b)
          } else {
            self.currentTrackDominantColor = nil
          }
        } else {
          self.currentTrackArtworkData = nil
          self.currentTrackDominantColor = nil
        }
        self.observeCurrentTrackChange()
      }
    }
  }

  /// Phase 96: When iPad switches between desktop UI and WPUI, reset stale state.
  private func observeUIModeSwitching() {
    withObservationTracking {
      _ = self.screenVM.isHorizontallyCompact
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        let isWPUI = WPPhoneViewModel.shouldUseWPUI(screenVM: self.screenVM)
        if isWPUI {
          // Entering WPUI: clear desktop-specific selections.
          self.gridVM.expandedAlbumID = nil
          self.gridVM.highlightedAlbumIDs.removeAll()
          self.selectedTrackIDs.removeAll()
          self.tableVM.isEditModeActive = false
        } else {
          // Entering desktop UI: clear WPUI-specific selections.
          self.phoneVM.wpSelectedAlbumIDs.removeAll()
        }
        self.observeUIModeSwitching()
      }
    }
  }

  /// Phase 121: Clear predicateEditorVM when the sheet is dismissed.
  private func observePredicateEditorDismissal() {
    withObservationTracking {
      _ = self.predicateEditorPlaylist
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.predicateEditorPlaylist == nil {
          self.predicateEditorVM = nil
        }
        self.observePredicateEditorDismissal()
      }
    }
  }

  // MARK: - Computed Helpers

  /// Schedule a debounced asynchronous search. Cancels prior pending search.
  private func scheduleSearch() {
    // Cancel any existing work
    searchTask?.cancel()

    let textSnapshot = searchText
    // If the query is empty, clear caches immediately on main actor.
    let trimmed = textSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      displayedTracksCache = []
      gridVM.displayedAlbumsCache = []
      isSearching = false
      return
    }

    isSearching = true
    // Debounced task — runs off the main actor so heavy filtering won't block UI.
    searchTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1.0s debounce
      } catch {
        return // cancelled
      }
      if Task.isCancelled { return }
      guard let self = self else { return }

      // Snapshot base tracks and filter config on the main actor.
      let (base, mode, genres, albumArtists, songArtists, albumTitles) = await MainActor.run {
        (
          self.baseTracks,
          self.searchFilterMode,
          self.columnBrowserSelectedGenres,
          self.columnBrowserSelectedAlbumArtists,
          self.columnBrowserSelectedSongArtists,
          self.columnBrowserSelectedAlbumTitles
        )
      }

      if Task.isCancelled { return }

      let tokens = searchTokens(from: textSnapshot)
      if tokens.isEmpty {
        await MainActor.run {
          if self.searchText == textSnapshot {
            self.displayedTracksCache = []
            self.gridVM.displayedAlbumsCache = []
            self.isSearching = false
          }
        }
        return
      }

      // Per-track filtering using the shared filter logic.
      var tracksResult: [Track] = []
      for track in base {
        if Task.isCancelled { return }
        // Column browser filters
        if !genres.isEmpty, !genres.contains(track.genre) { continue }
        if !albumArtists.isEmpty, !albumArtists.contains(track.albumArtist) { continue }
        if !songArtists.isEmpty, !songArtists.contains(track.artist) { continue }
        if !albumTitles.isEmpty, !albumTitles.contains(track.albumTitle) { continue }
        // Search filter (shared logic)
        if self.trackMatchesSearch(track, tokens: tokens, mode: mode) {
          tracksResult.append(track)
        }
      }

      if Task.isCancelled { return }

      // Build albums from filtered tracks using unfilteredAlbums for metadata.
      let unfilteredAlbumsSnapshot: [Album] = await MainActor.run { self.gridVM.unfilteredAlbums }
      if Task.isCancelled { return }

      let filteredIDs = Set(tracksResult.map(\.id))
      var albumsResult: [Album] = []
      for album in unfilteredAlbumsSnapshot {
        if Task.isCancelled { return }
        let matching = album.tracks.filter { filteredIDs.contains($0.id) }
        if !matching.isEmpty {
          albumsResult.append(Album(
            id: album.id,
            title: album.title,
            artist: album.artist,
            tracks: matching
          ))
        }
      }

      if Task.isCancelled { return }

      let sortedAlbumsResult = await MainActor.run { self.gridVM.sortedAlbums(albumsResult)
      }

      if Task.isCancelled { return }

      // Commit results on main actor only if query hasn't changed.
      await MainActor.run {
        if self.searchText == textSnapshot {
          self.displayedTracksCache = tracksResult
          self.gridVM.displayedAlbumsCache = sortedAlbumsResult
          self.isSearching = false
        }
      }
    }
  }
}
