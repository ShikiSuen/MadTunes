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
  var selectedPlaylistID: UUID?
  var expandedAlbumID: UUID?
  var highlightedAlbumIDs: Set<UUID> = []
  var selectedTrackIDs: Set<UUID> = []
  /// The fixed anchor for Shift+Arrow range selection. Set on click / plain arrow.
  var albumSelectionFixedAnchorID: UUID?
  /// The moving cursor for Shift+Arrow range selection.
  var albumSelectionCursorID: UUID?
  var isFileImporterPresented = false // Only for non-AppKit targets.
  var isFolderImporterPresented = false // Also used on macOS AppKit as File Importer.
  var isDropTargeted = false
  var albumSortOrder: AlbumSortOrder = .artistYearTitle
  var screenVM = ScreenVM.shared

  // Keyword search
  var searchText: String = ""
  var searchFilterMode: SearchFilterMode = .either

  // Scroll-to-album trigger (set by artwork double-click, consumed by AlbumGridView)
  var scrollToAlbumID: UUID?

  // Column Browser filter state (empty set = "All")
  var columnBrowserSelectedGenres: Set<String> = []
  /// Newly split from previous `Artists`; refers to the album-level artist.
  var columnBrowserSelectedAlbumArtists: Set<String> = []
  /// Separate song-artist filter (tracks' artist field).
  var columnBrowserSelectedSongArtists: Set<String> = []
  var columnBrowserSelectedAlbumTitles: Set<String> = []

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

  var currentAlbums: [Album] {
    var result = unfilteredAlbums
    if !columnBrowserSelectedGenres.isEmpty {
      result = result.filter { album in
        album.tracks.contains { columnBrowserSelectedGenres.contains($0.genre) }
      }
    }
    if !columnBrowserSelectedAlbumArtists.isEmpty {
      result = result.filter { columnBrowserSelectedAlbumArtists.contains($0.artist) }
    }
    if !columnBrowserSelectedSongArtists.isEmpty {
      result = result.filter { album in
        album.tracks.contains { columnBrowserSelectedSongArtists.contains($0.artist) }
      }
    }
    if !columnBrowserSelectedAlbumTitles.isEmpty {
      result = result.filter { columnBrowserSelectedAlbumTitles.contains($0.title) }
    }
    let query = searchText.trimmingCharacters(in: .whitespaces)
    if !query.isEmpty {
      result = result.filter { album in
        // 先檢查專輯層級的欄位（根據過濾模式）
        let albumMatches: Bool = switch searchFilterMode {
        case .trackTitle:
          false // 專輯標題不屬於曲目名稱
        case .albumTitle:
          album.title.localizedCaseInsensitiveContains(query)
        case .artist:
          album.artist.localizedCaseInsensitiveContains(query)
        case .either:
          album.title.localizedCaseInsensitiveContains(query)
            || album.artist.localizedCaseInsensitiveContains(query)
        }

        // 檢查曲目層級的欄位
        let trackMatches = album.tracks.contains { track in
          switch searchFilterMode {
          case .trackTitle:
            track.title.localizedCaseInsensitiveContains(query)
          case .albumTitle:
            false // 專輯名稱模式不檢查曲目層級
          case .artist:
            track.artist.localizedCaseInsensitiveContains(query)
              || track.albumArtist.localizedCaseInsensitiveContains(query)
          case .either:
            track.title.localizedCaseInsensitiveContains(query)
              || track.artist.localizedCaseInsensitiveContains(query)
              || track.albumArtist.localizedCaseInsensitiveContains(query)
          }
        }

        return albumMatches || trackMatches
      }
    }
    return sortedAlbums(result)
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

  /// Resets column browser filters.
  func resetColumnBrowserFilters() {
    columnBrowserSelectedGenres = []
    columnBrowserSelectedAlbumArtists = []
    columnBrowserSelectedSongArtists = []
    columnBrowserSelectedAlbumTitles = []
  }

  /// Plays all tracks matching the current column browser filter state.
  func playFilteredTracks() {
    let tracks = currentAlbums.flatMap(\.tracks)
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

  func onTrackSelected(_ track: Track, _ albumTracks: [Track]) {
    player.setQueue(albumTracks, startingAt: albumTracks.firstIndex(of: track) ?? 0)
  }

  func onAlbumDoubleClicked(_ album: Album) {
    let tracks = filteredTracksForPlayback(from: album)
    guard let firstTrack = tracks.first else { return }
    guard let startIndex = tracks.firstIndex(where: { $0.id == firstTrack.id }) else { return }
    player.setQueue(tracks, startingAt: startIndex)
    highlightedAlbumIDs = [album.id]
  }

  /// 從專輯中取得符合當前搜尋條件的曲目，用於播放。
  /// 如果沒有搜尋條件，返回該專輯所有曲目。
  func filteredTracksForPlayback(from album: Album) -> [Track] {
    let query = searchText.trimmingCharacters(in: .whitespaces)
    let allTracks = album.tracks

    guard !query.isEmpty else {
      return allTracks
    }

    // 專輯名稱模式：如果該專輯符合搜尋條件，返回所有曲目；否則返回空陣列
    if searchFilterMode == .albumTitle {
      return album.title.localizedCaseInsensitiveContains(query) ? allTracks : []
    }

    return allTracks.filter { track in
      switch searchFilterMode {
      case .trackTitle:
        return track.title.localizedCaseInsensitiveContains(query)
      case .albumTitle:
        return true // 已由上方處理
      case .artist:
        return track.artist.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
      case .either:
        return track.title.localizedCaseInsensitiveContains(query)
          || track.artist.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
      }
    }
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
    highlightedAlbumIDs = Set(currentAlbums.map(\.id))
  }

  /// 獲取指定專輯中經過篩選的曲目（與 ExpandedAlbumView 邏輯一致）
  func filteredTracks(for album: Album) -> [Track] {
    let query = searchText.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return album.tracks }

    let filtered: [Track] = switch searchFilterMode {
    case .trackTitle:
      album.tracks.filter { track in
        track.title.localizedCaseInsensitiveContains(query)
      }
    case .albumTitle:
      album.title.localizedCaseInsensitiveContains(query) ? album.tracks : []
    case .artist:
      album.tracks.filter { track in
        track.artist.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
      }
    case .either:
      album.tracks.filter { track in
        track.title.localizedCaseInsensitiveContains(query)
          || track.artist.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
      }
    }
    // 如果過濾後為空，但專輯本身符合搜尋條件，則顯示所有曲目
    if filtered.isEmpty {
      let albumMatches = album.title.localizedCaseInsensitiveContains(query)
        || album.artist.localizedCaseInsensitiveContains(query)
      return albumMatches ? album.tracks : filtered
    }
    return filtered
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

  // MARK: Private

  private let minItemWidth: CGFloat = 160
  private let gridSpacing: CGFloat = 16

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
