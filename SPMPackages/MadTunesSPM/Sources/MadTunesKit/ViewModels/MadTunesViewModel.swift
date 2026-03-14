// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - MadTunesViewModel

@Observable
@MainActor
final class MadTunesViewModel {
  // MARK: Internal

  static let shared = MadTunesViewModel()

  var library = MusicLibrary()
  var player = AudioPlayer()

  // Phase 60: Sub-ViewModels for table and grid views.
  var tableVM = AlbumTableViewModel()
  var gridVM = AlbumGridViewModel()

  var selectedPlaylistID: UUID?
  var expandedAlbumID: UUID?
  var highlightedAlbumIDs: Set<UUID> = []
  var selectedTrackIDs: Set<UUID> = []
  /// When true the main content area shows AlbumTableView instead of AlbumGridView.
  /// Persisted via UserDefaults.
  var useTableView: Bool = UserDefaults.standard.bool(forKey: "MadTunes.useTableView")

  /// The fixed anchor for Shift+Arrow range selection. Set on click / plain arrow.
  var albumSelectionFixedAnchorID: UUID?
  /// The moving cursor for Shift+Arrow range selection.
  var albumSelectionCursorID: UUID?

  /// Table view: anchor for Shift+Click/Arrow range selection.
  var tableSelectionAnchorID: UUID?
  /// Table view: moving cursor (highlighted row).
  var tableSelectionCursorID: UUID?
  /// Phase 42: Set during keyboard navigation to auto-scroll the table.
  /// Not set on mouse click; reset to nil after the scroll completes.
  var tableScrollTargetID: UUID?

  /// Phase 44: Table view column sorting (column type, ascending?)
  var tableSortCriteria: (column: TableColumnType, ascending: Bool)?

  var isFileImporterPresented = false // Only for non-AppKit targets.
  var isFolderImporterPresented = false // Also used on macOS AppKit as File Importer.
  var isDropTargeted = false
  var albumSortOrder: AlbumSortOrder = .artistYearTitle
  var screenVM = ScreenVM.shared

  var searchFilterMode: SearchFilterMode = .either

  var displayedTracksCache: [Track] = []
  var displayedAlbumsCache: [Album] = []
  var isSearching: Bool = false
  // Scroll-to-album trigger (set by artwork double-click, consumed by AlbumGridView)
  var scrollToAlbumID: UUID?

  // Column Browser filter state (empty set = "All")
  var columnBrowserSelectedGenres: Set<String> = []
  /// Newly split from previous `Artists`; refers to the album-level artist.
  var columnBrowserSelectedAlbumArtists: Set<String> = []
  /// Separate song-artist filter (tracks' artist field).
  var columnBrowserSelectedSongArtists: Set<String> = []
  var columnBrowserSelectedAlbumTitles: Set<String> = []

  // Keyword search
  var searchText: String = "" {
    didSet {
      scheduleSearch()
    }
  }

  var gridColumnCount: Int {
    let width = screenVM.mainColumnCanvasSizeObserved.width
    return max(1, Int((width - gridSpacing) / (minItemWidth + gridSpacing)))
  }

  /// Number of albums to scroll per page (PgUp/PgDown).
  /// Estimates visible rows based on screen height and item dimensions.
  var gridPageSize: Int {
    let canvasHeight = screenVM.mainColumnCanvasSizeObserved.height
    // Approximate item height: scaled artwork (160 * 0.92) + text area (~50) + padding
    let approximateRowHeight: CGFloat = 160 + 50 + gridSpacing
    let visibleRows = max(1, Int((canvasHeight - 100) / approximateRowHeight)) // 100 for player controls
    return visibleRows * gridColumnCount
  }

  /// Flat track list for table view (filtered + table-sorted).
  /// Replaces the old `currentTracks` / `currentTracks(fromAlbums:)`.
  var currentTracksDisplayed: [Track] {
    let tracks = filteredTracksBase
    guard let criteria = tableSortCriteria else { return tracks }
    return sortedTracks(tracks, by: criteria)
  }

  /// Albums for grid view, derived from filtered tracks.
  /// Each album contains ONLY the tracks that passed all filters.
  /// Replaces the old `currentAlbums`.
  var currentAlbumsDisplayed: [Album] {
    let tokens = searchTokens(from: searchText)
    // When search is active and cache is ready, use cached albums.
    if !tokens.isEmpty, !displayedAlbumsCache.isEmpty || isSearching {
      return displayedAlbumsCache
    }

    return buildAlbumsFromFilteredTracks(filteredTracksBase)
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
    let genres = Set(unfilteredAlbums.flatMap { $0.tracks.map(\.genre) })
    return genres.filter { !$0.isEmpty }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Unique artists available given the current genre filter.
  /// Album–level artists available given current genre filter.
  var columnBrowserAlbumArtists: [String] {
    var source = unfilteredAlbums
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
    var source = unfilteredAlbums
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
    var source = unfilteredAlbums
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

  var currentTrackArtwork: Data? {
    guard let track = player.currentTrack else { return nil }
    let key = library.albumKey(title: track.albumTitle, artist: track.albumArtist)
    return library.artworkCache[key]
  }

  /// Whether the currently selected playlist supports drag‑reordering.
  ///
  /// Enabled for user static playlists and Favorites, disabled for All Music and
  /// any dynamic playlists. Also disabled when table sorting is active to avoid
  /// reordering a sorted view.
  var canReorderCurrentPlaylist: Bool {
    guard let playlistID = selectedPlaylistID,
          let index = library.playlists.firstIndex(where: { $0.id == playlistID })
    else {
      return false
    }
    // All Music (index 0) should never be reorderable.
    if index == 0 { return false }

    let playlist = library.playlists[index]
    let isFavorites = playlist.kind == .system && index == 1
    let isStatic = playlist.kind == .staticList
    // Don't allow reordering while the table is sorted or filtered, since the
    // visible order would not map cleanly back to the playlist order.
    let canReorder = (isFavorites || isStatic)
      && tableSortCriteria == nil
      && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isColumnBrowserFiltering
    return canReorder
  }

  // MARK: - Phase 52: Menu command helpers for track reordering

  /// Whether the selected tracks can be moved up in the current playlist.
  var canMoveSelectedTracksUp: Bool {
    guard useTableView, canReorderCurrentPlaylist, !selectedTrackIDs.isEmpty else { return false }
    let tracks = currentTracksDisplayed
    let firstSelectedIdx = tracks.firstIndex { selectedTrackIDs.contains($0.id) }
    return (firstSelectedIdx ?? 0) > 0
  }

  /// Whether the selected tracks can be moved down in the current playlist.
  var canMoveSelectedTracksDown: Bool {
    guard useTableView, canReorderCurrentPlaylist, !selectedTrackIDs.isEmpty else { return false }
    let tracks = currentTracksDisplayed
    let lastSelectedIdx = tracks.lastIndex { selectedTrackIDs.contains($0.id) }
    return (lastSelectedIdx ?? tracks.count - 1) < tracks.count - 1
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

  func moveTracksInCurrentPlaylist(trackIDs: [UUID], toIndex: Int) {
    guard canReorderCurrentPlaylist, let playlistID = selectedPlaylistID else { return }
    library.moveTracks(trackIDs, inPlaylist: playlistID, toIndex: toIndex)
  }

  /// Moves selected tracks one position up. Called by menu command (Option+↑).
  func moveSelectedTracksUp() {
    let tracks = currentTracksDisplayed
    let orderedSelected = tracks.enumerated().filter { selectedTrackIDs.contains($0.element.id) }
    guard let firstIdx = orderedSelected.first?.offset, firstIdx > 0 else { return }
    moveTracksInCurrentPlaylist(trackIDs: orderedSelected.map(\.element.id), toIndex: firstIdx - 1)
  }

  /// Moves selected tracks one position down. Called by menu command (Option+↓).
  func moveSelectedTracksDown() {
    let tracks = currentTracksDisplayed
    let orderedSelected = tracks.enumerated().filter { selectedTrackIDs.contains($0.element.id) }
    guard let lastIdx = orderedSelected.last?.offset, lastIdx < tracks.count - 1 else { return }
    moveTracksInCurrentPlaylist(trackIDs: orderedSelected.map(\.element.id), toIndex: lastIdx + 2)
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
    player.setQueue(tracks, startingAt: 0)
  }

  // MARK: - Sorting

  func sortedAlbums(_ albums: [Album]) -> [Album] {
    albums.sorted { a, b in
      switch albumSortOrder {
      case .artistYearTitle:
        let cmp = a.artist.localizedCaseInsensitiveCompare(b.artist)
        if cmp != .orderedSame { return cmp == .orderedAscending }
        let y1 = a.year ?? Int.max, y2 = b.year ?? Int.max
        if y1 != y2 { return y1 < y2 }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
      case .artistTitleYear:
        let cmp = a.artist.localizedCaseInsensitiveCompare(b.artist)
        if cmp != .orderedSame { return cmp == .orderedAscending }
        let cmp2 = a.title.localizedCaseInsensitiveCompare(b.title)
        if cmp2 != .orderedSame { return cmp2 == .orderedAscending }
        let y1 = a.year ?? Int.max, y2 = b.year ?? Int.max
        return y1 < y2
      case .yearArtistTitle:
        let y1 = a.year ?? Int.max, y2 = b.year ?? Int.max
        if y1 != y2 { return y1 < y2 }
        let cmp = a.artist.localizedCaseInsensitiveCompare(b.artist)
        if cmp != .orderedSame { return cmp == .orderedAscending }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
      }
    }
  }

  /// Sorts tracks by the given table column criteria.
  /// Uses pre-computed `Track.folderPath` to avoid repeated URL operations.
  func sortedTracks(_ tracks: [Track], by criteria: (column: TableColumnType, ascending: Bool)) -> [Track] {
    let ascending = criteria.ascending
    return tracks.sorted {
      switch criteria.column {
      case .name:
        return ascending ? $0.title < $1.title : $0.title > $1.title
      case .length:
        return ascending ? $0.duration < $1.duration : $0.duration > $1.duration
      case .artist:
        return ascending ? $0.artist < $1.artist : $0.artist > $1.artist
      case .albumTitle:
        return ascending ? $0.albumTitle < $1.albumTitle : $0.albumTitle > $1.albumTitle
      case .albumArtist:
        return ascending ? $0.albumArtist < $1.albumArtist : $0.albumArtist > $1.albumArtist
      case .trackNumber:
        let disc0 = $0.discNumber, disc1 = $1.discNumber
        let track0 = $0.trackNumber, track1 = $1.trackNumber
        if disc0 != disc1 {
          return ascending ? disc0 < disc1 : disc0 > disc1
        }
        return ascending ? track0 < track1 : track0 > track1
      case .genre:
        return ascending ? $0.genre < $1.genre : $0.genre > $1.genre
      case .year:
        let y0 = $0.year ?? Int.min, y1 = $1.year ?? Int.min
        return ascending ? y0 < y1 : y0 > y1
      case .folder:
        return ascending ? $0.folderPath < $1.folderPath : $0.folderPath > $1.folderPath
      case .playingIndicator:
        return ascending ? $0.title < $1.title : $0.title > $1.title
      }
    }
  }

  func onTrackSelected(_ track: Track, _ albumTracks: [Track]) {
    player.setQueue(albumTracks, startingAt: albumTracks.firstIndex(of: track) ?? 0)
  }

  func onAlbumDoubleClicked(_ album: Album) {
    // Album passed here is already filtered (contains only matching tracks).
    let tracks = album.tracks
    guard !tracks.isEmpty else { return }
    player.setQueue(tracks, startingAt: 0)
    highlightedAlbumIDs = [album.id]
  }

  func importURLs(_ urls: [URL]) {
    // Capture the playlist that was active when the import started.
    let targetPlaylistID = selectedPlaylistID
    Task {
      await library.importFiles(urls: urls)

      // After the import finishes, if the user was viewing anything other than
      // "All Music" we should also add the imported items to that playlist.
      // This covers the Favorites page (index 1) and any user-defined static
      // playlist. The operation is performed even if some of the files were
      // duplicates (the helper will simply skip entries that already exist in
      // the playlist).
      if let pid = targetPlaylistID,
         pid != library.playlists.first?.id {
        // Determine which track IDs correspond to the imported URLs. We
        // compare file paths since URLs may not be identical objects.
        let importedPaths = Set(urls.map { $0.standardizedFileURL.path })
        let idsToAdd = library.tracks
          .filter { importedPaths.contains($0.fileURL.standardizedFileURL.path) }
          .map(\.id)
        if !idsToAdd.isEmpty {
          library.addTracks(Set(idsToAdd), toPlaylist: pid)
        }
      }
    }
  }

  // MARK: - Drop Handling

  func handleDrop(_ providers: [NSItemProvider]) -> Bool {
    var found = false
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier("public.file-url") {
        found = true
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
          guard let data = data as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
          else { return }
          #if os(macOS) || targetEnvironment(macCatalyst)
          let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          #else
          let bookmark: Data? = try? url.bookmarkData()
          #endif
          Task { @MainActor in
            if let bookmark {
              var stale = false
              #if os(macOS) || targetEnvironment(macCatalyst)
              if let scopedURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
              ) {
                _ = scopedURL.startAccessingSecurityScopedResource()
                self.importURLs([scopedURL])
                return
              }
              #endif
            }
            self.importURLs([url])
          }
        }
      }
    }
    return found
  }

  // MARK: - Select All & Copy

  /// 選中所有肉眼可見的專輯（受 Column Browser 與搜尋篩選影響）
  func selectAllVisibleAlbums() {
    highlightedAlbumIDs = Set(currentAlbumsDisplayed.map(\.id))
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

  // MARK: - Keyboard Navigation

  func handleKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    // When table view is active, delegate to table-specific handler.
    if useTableView {
      return handleTableKeyPress(press)
    }
    // CMD+A: Select All
    if press.characters == "a", press.modifiers.contains(.command) {
      if let expandedID = expandedAlbumID,
         let album = albums.first(where: { $0.id == expandedID }) {
        // 有專輯展開時，選中該專輯下所有可見曲目
        selectAllVisibleTracks(in: album)
      } else {
        // 沒有專輯展開時，選中所有可見專輯
        selectAllVisibleAlbums()
      }
      return .handled
    }

    // CMD+C: Copy selected tracks metadata (only when album expanded and tracks selected)
    if press.characters == "c", press.modifiers.contains(.command) {
      if expandedAlbumID != nil, !selectedTrackIDs.isEmpty {
        copySelectedTracksMetadata()
        return .handled
      }
    }

    // Spacebar: prioritise toggling play/pause when a track is loaded,
    // but only when an album is expanded.
    spaceTask: if press.characters == " " {
      let hasAlbumExpanded = expandedAlbumID != nil
      switch press.modifiers {
      case [] where player.currentTrack != nil && hasAlbumExpanded:
        player.togglePlayPause()
        return .handled
      case [.shift] where !(player.currentTrack != nil && hasAlbumExpanded):
        player.togglePlayPause()
        return .handled
      default: break spaceTask
      }
    }

    switch albums.first(where: { $0.id == expandedAlbumID }) {
    case .none:
      // album 沒有命中，此時 expandedAlbumID 必然為 nil。
      return handleGridKeyPress(press, albums: albums)
    case let .some(album):
      let result = handleExpandedKeyPress(press, album: album, albums: albums)
      if result == .handled { return .handled }
    }

    return .ignored
  }

  // MARK: - Table Keyboard Navigation

  /// Handles keyboard input when the table view is active.
  /// Phase 52: Now backed by List instead of Table. Arrow keys, Shift+Arrow,
  /// PgUp/PgDn are handled natively by the List. Track reorder (Option+↑/↓)
  /// is handled via menu commands in MadTunesScene. This handler intercepts:
  /// Cmd+C copy, Cmd+↓/Return/Space to play.
  func handleTableKeyPress(_ press: KeyPress) -> KeyPress.Result {
    let tracks = currentTracksDisplayed
    guard !tracks.isEmpty else { return .ignored }

    // CMD+C: Copy selected tracks metadata.
    if press.characters == "c", press.modifiers.contains(.command) {
      if !selectedTrackIDs.isEmpty {
        copySelectedTracksMetadata()
        return .handled
      }
    }

    // Phase 42: CMD+↓: Play selected tracks immediately.
    if press.key == .downArrow, press.modifiers.contains(.command) {
      let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
      if !selected.isEmpty {
        player.setQueue(selected, startingAt: 0)
        return .handled
      }
      return .handled
    }

    // Return / Space: play selected tracks (or track at cursor).
    if press.key == .return || press.characters == " " {
      if press.characters == " ", player.currentTrack != nil {
        player.togglePlayPause()
        return .handled
      }
      let selected = tracks.filter { selectedTrackIDs.contains($0.id) }
      if !selected.isEmpty {
        player.setQueue(selected, startingAt: 0)
        return .handled
      }
      return .ignored
    }

    // Phase 47: All other keys (arrows, page, etc.) fall through to Table.
    return .ignored
  }

  // MARK: - Phase 44: Table Sorting

  // Phase 44: Clear sorting (switch back to album order)
  func clearTableSorting() {
    tableSortCriteria = nil
  }

  // Phase 44: Set or toggle column sort
  func setTableSort(column: TableColumnType) {
    if let current = tableSortCriteria, current.column == column {
      // Toggle direction
      let newAscending = !current.ascending
      if newAscending {
        // Third click: clear sort
        tableSortCriteria = nil
      } else {
        tableSortCriteria = (column: column, ascending: newAscending)
      }
    } else {
      tableSortCriteria = (column: column, ascending: true)
    }
  }

  // Phase 44: Get sort indicator for column header
  func sortIndicator(for column: TableColumnType) -> String? {
    guard let criteria = tableSortCriteria, criteria.column == column else { return nil }
    return criteria.ascending ? " ▲" : " ▼"
  }

  // MARK: Private

  // --- Async search/cache (Phase 57):
  // Cached filtered results produced by the debounced async search task.
  private var searchTask: Task<Void, Never>?

  private let minItemWidth: CGFloat = 160
  private let gridSpacing: CGFloat = 16

  // MARK: - Phase 58: New Data Pipeline (Single-Filter)

  /// Base tracks for the current playlist, before any filtering.
  /// Preserves playlist ordering for static/Favorites playlists.
  private var baseTracks: [Track] {
    if let playlistID = selectedPlaylistID,
       let playlist = library.playlists.first(where: { $0.id == playlistID }),
       playlist.id != library.playlists.first?.id {
      return library.tracks(for: playlist)
    }
    return library.tracks
  }

  /// Single source of truth: all displayable tracks after applying all filters.
  /// Does NOT apply table sort — call `currentTracksDisplayed` for the sorted version.
  private var filteredTracksBase: [Track] {
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

  // MARK: - Computed Helpers

  /// Albums from the current playlist, before column browser filtering.
  private var unfilteredAlbums: [Album] {
    if let playlistID = selectedPlaylistID,
       let playlist = library.playlists.first(where: { $0.id == playlistID }),
       playlist.id != library.playlists.first?.id {
      return library.albums(for: playlist)
    }
    return library.albums
  }

  /// Groups a flat filtered track list back into Album objects, preserving
  /// original album metadata (id, artworkData) via `unfilteredAlbums`.
  private func buildAlbumsFromFilteredTracks(_ filteredTracks: [Track]) -> [Album] {
    let filteredIDs = Set(filteredTracks.map(\.id))
    let albums = unfilteredAlbums.compactMap { album -> Album? in
      let matching = album.tracks.filter { filteredIDs.contains($0.id) }
      guard !matching.isEmpty else { return nil }
      return Album(
        id: album.id,
        title: album.title,
        artist: album.artist,
        tracks: matching,
        artworkData: album.artworkData
      )
    }
    return sortedAlbums(albums)
  }

  /// Schedule a debounced asynchronous search. Cancels prior pending search.
  private func scheduleSearch() {
    // Cancel any existing work
    searchTask?.cancel()

    let textSnapshot = searchText
    // If the query is empty, clear caches immediately on main actor.
    let trimmed = textSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      displayedTracksCache = []
      displayedAlbumsCache = []
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
            self.displayedAlbumsCache = []
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
      let unfilteredAlbumsSnapshot: [Album] = await MainActor.run { self.unfilteredAlbums }
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
            tracks: matching,
            artworkData: album.artworkData
          ))
        }
      }

      if Task.isCancelled { return }

      let sortedAlbumsResult = await MainActor.run { self.sortedAlbums(albumsResult) }

      if Task.isCancelled { return }

      // Commit results on main actor only if query hasn't changed.
      await MainActor.run {
        if self.searchText == textSnapshot {
          self.displayedTracksCache = tracksResult
          self.displayedAlbumsCache = sortedAlbumsResult
          self.isSearching = false
        }
      }
    }
  }

  private func handleGridKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    guard !albums.isEmpty else { return .ignored }

    handleArrowKey: if press.isArrowKey {
      // 此處使用 `press.modifiers == [.shift]` 反而無效。
      let isShift = press.modifiers.contains(.shift)

      // For Shift: navigate from the moving cursor. For plain: from any highlighted.
      let referenceID: UUID? = isShift
        ? (albumSelectionCursorID ?? highlightedAlbumIDs.first)
        : highlightedAlbumIDs.first

      guard let hID = referenceID,
            let idx = albums.firstIndex(where: { $0.id == hID }) else {
        let firstID = albums[0].id
        highlightedAlbumIDs = [firstID]
        albumSelectionFixedAnchorID = firstID
        albumSelectionCursorID = firstID
        return .handled
      }

      let newIdx: Int
      switch press.key {
      case .rightArrow:
        newIdx = min(idx + 1, albums.count - 1)
      case .leftArrow:
        newIdx = max(idx - 1, 0)
      case .downArrow:
        newIdx = min(idx + gridColumnCount, albums.count - 1)
      case .upArrow:
        newIdx = max(idx - gridColumnCount, 0)
      default:
        break handleArrowKey
      }

      if isShift {
        // Windows Explorer-style Shift+arrow selection.
        // Selection is always the range between fixed anchor and moving cursor.
        let anchorID: UUID
        if let existing = albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = highlightedAlbumIDs.first {
          anchorID = first
          albumSelectionFixedAnchorID = anchorID
        } else {
          // No existing selection: start fresh
          let newID = albums[newIdx].id
          highlightedAlbumIDs = [newID]
          albumSelectionFixedAnchorID = newID
          albumSelectionCursorID = newID
          expandedAlbumID = nil
          if newIdx != idx {
            scrollToAlbumID = newID
          }
          return .handled
        }

        guard let anchorIdx = albums.firstIndex(where: { $0.id == anchorID }) else {
          return .handled
        }

        // Update cursor and compute selection range
        let cursorIdx = newIdx
        albumSelectionCursorID = albums[cursorIdx].id

        let lo = min(anchorIdx, cursorIdx)
        let hi = max(anchorIdx, cursorIdx)
        highlightedAlbumIDs = Set(albums[lo ... hi].map(\.id))
        expandedAlbumID = nil
      } else {
        let newID = albums[newIdx].id
        highlightedAlbumIDs = [newID]
        albumSelectionFixedAnchorID = newID
        albumSelectionCursorID = newID
      }

      // scroll regardless of selection count when the index actually moved
      if newIdx != idx {
        scrollToAlbumID = albums[newIdx].id
      }

      return .handled
    }

    handlePageKey: if press.isPageKey {
      let isShift = press.modifiers.contains(.shift)
      let pageDelta = gridPageSize
      guard pageDelta > 0 else { break handlePageKey }

      // Determine reference point: cursor if available, otherwise first selected
      let referenceID: UUID? = albumSelectionCursorID ?? highlightedAlbumIDs.first

      guard let hID = referenceID,
            let idx = albums.firstIndex(where: { $0.id == hID }) else {
        // No selection: start from beginning or end based on direction
        let isPageDown = press.key == .pageDown
        let targetIdx = isPageDown ? min(pageDelta, albums.count - 1) : 0
        let targetID = albums[targetIdx].id
        highlightedAlbumIDs = [targetID]
        albumSelectionFixedAnchorID = targetID
        albumSelectionCursorID = targetID
        scrollToAlbumID = targetID
        return .handled
      }

      // Calculate new index after page scroll
      let isPageDown = press.key == .pageDown
      let newIdx: Int
      if isPageDown {
        newIdx = min(idx + pageDelta, albums.count - 1)
      } else {
        newIdx = max(idx - pageDelta, 0)
      }

      if isShift {
        // Shift+PgUp/PgDn: range selection
        // Phase 37: If paging reveals a new anchor (first item on new page becomes anchor)
        let anchorID: UUID
        if let existing = albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = highlightedAlbumIDs.first {
          anchorID = first
          albumSelectionFixedAnchorID = anchorID
        } else {
          // No anchor: start fresh with current position as anchor
          anchorID = albums[idx].id
          albumSelectionFixedAnchorID = anchorID
        }

        guard let anchorIdx = albums.firstIndex(where: { $0.id == anchorID }) else {
          return .handled
        }

        // Update cursor to new page position
        albumSelectionCursorID = albums[newIdx].id

        // Compute selection range
        let lo = min(anchorIdx, newIdx)
        let hi = max(anchorIdx, newIdx)
        highlightedAlbumIDs = Set(albums[lo ... hi].map(\.id))
        expandedAlbumID = nil
      } else {
        // Plain PgUp/PgDn: move cursor and reset selection
        let newID = albums[newIdx].id
        highlightedAlbumIDs = [newID]
        albumSelectionFixedAnchorID = newID
        albumSelectionCursorID = newID
      }

      scrollToAlbumID = albums[newIdx].id
      return .handled
    }

    if press.isAlbumExpansionAssignmentKey {
      if highlightedAlbumIDs.count == 1 {
        withAnimation(.easeInOut(duration: 0.3)) {
          // 此時 first 必命中，無須 guard-let。
          expandedAlbumID = highlightedAlbumIDs.first
        }
        return .handled
      }
      return .ignored
    }

    return .ignored
  }

  private func handleExpandedKeyPress(
    _ press: KeyPress, album: Album, albums: [Album]
  )
    -> KeyPress.Result {
    let sorted = album.tracks
    guard !sorted.isEmpty else {
      // 允許 Escape 鍵關閉空專輯
      if press.key == .escape || (press.modifiers.contains(.command) && press.key == .upArrow) {
        withAnimation(.easeInOut(duration: 0.3)) { expandedAlbumID = nil }
        return .handled
      }
      return .ignored
    }

    if press.key == .escape
      || (press.modifiers.contains(.command) && press.key == .upArrow) {
      withAnimation(.easeInOut(duration: 0.3)) {
        expandedAlbumID = nil
      }
      return .handled
    }

    if press.isAlbumExpansionAssignmentKey {
      let selectedSorted = sorted.filter { selectedTrackIDs.contains($0.id) }
      if !selectedSorted.isEmpty {
        player.setQueue(selectedSorted, startingAt: 0)
        return .handled
      }
      withAnimation(.easeInOut(duration: 0.3)) {
        expandedAlbumID = nil
      }
      return .handled
    }

    if press.isArrowKey {
      if selectedTrackIDs.isEmpty {
        switch press.key {
        case .downArrow:
          if let first = sorted.first {
            selectedTrackIDs = [first.id]
          }
          return .handled
        case .upArrow:
          withAnimation(.easeInOut(duration: 0.3)) {
            expandedAlbumID = nil
          }
          return .handled
        default:
          return navigateAlbumFromExpanded(press, albums: albums)
        }
      }

      guard let anchorID = selectedTrackIDs.first(where: { _ in true }),
            let anchorIdx = sorted.firstIndex(where: { $0.id == anchorID })
      else { return .handled }

      let maxRowsPerColumn = 7
      let trackListWidth = max(300, screenVM.mainColumnCanvasSizeObserved.width - 292)
      let minColumnWidth: CGFloat = 300
      let maxPossibleColumns = max(1, Int(trackListWidth / minColumnWidth))
      let desiredColumns = sorted.count > maxRowsPerColumn ? maxPossibleColumns : 1
      let columnCount = max(1, min(sorted.count, desiredColumns))
      // Defensive: avoid division by zero; itemsPerColumn is at least 1 when sorted is not empty.
      let itemsPerColumn = sorted.isEmpty ? 0 : Int(ceil(Double(sorted.count) / Double(columnCount)))

      switch press.key {
      case .upArrow:
        let firstIdx = sorted.firstIndex(where: { selectedTrackIDs.contains($0.id) }) ?? anchorIdx
        if firstIdx == 0 {
          selectedTrackIDs.removeAll()
        } else {
          selectedTrackIDs = [sorted[firstIdx - 1].id]
        }
      case .downArrow:
        let lastIdx = sorted.lastIndex(where: { selectedTrackIDs.contains($0.id) }) ?? anchorIdx
        if lastIdx >= sorted.count - 1 {
          withAnimation(.easeInOut(duration: 0.3)) {
            expandedAlbumID = nil
          }
          selectedTrackIDs.removeAll()
        } else {
          selectedTrackIDs = [sorted[lastIdx + 1].id]
        }
      case .rightArrow:
        let newIdx = min(anchorIdx + itemsPerColumn, sorted.count - 1)
        selectedTrackIDs = [sorted[newIdx].id]
      case .leftArrow:
        let newIdx = max(anchorIdx - itemsPerColumn, 0)
        selectedTrackIDs = [sorted[newIdx].id]
      default:
        break
      }
      return .handled
    }

    return .ignored
  }

  private func navigateAlbumFromExpanded(
    _ press: KeyPress, albums: [Album]
  )
    -> KeyPress.Result {
    guard let hID = highlightedAlbumIDs.first ?? expandedAlbumID,
          let idx = albums.firstIndex(where: { $0.id == hID }) else {
      return .ignored
    }
    let newIdx: Int
    switch press.key {
    case .rightArrow:
      newIdx = min(idx + 1, albums.count - 1)
    case .leftArrow:
      newIdx = max(idx - 1, 0)
    default:
      newIdx = max(idx - gridColumnCount, 0)
    }
    guard newIdx != idx else { return .handled }
    let newAlbumID = albums[newIdx].id
    withAnimation(.easeInOut(duration: 0.3)) {
      highlightedAlbumIDs = [newAlbumID]
      expandedAlbumID = newAlbumID
    }
    return .handled
  }
}

extension KeyPress {
  public var isArrowKey: Bool {
    [.upArrow, .downArrow, .leftArrow, .rightArrow].contains(key)
  }

  public var isPageKey: Bool {
    key == .pageUp || key == .pageDown
  }

  public var isAlbumExpansionAssignmentKey: Bool {
    switch key {
    case .return: return true
    case .downArrow: return modifiers.contains(.command)
    default: return characters == " "
    }
  }
}
