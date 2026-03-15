// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation
import SwiftUI

// MARK: - AlbumTableViewModel

/// Phase 60: Sub-ViewModel for AlbumTableView.
/// Extracts column visibility/width persistence, display buffering,
/// and context-menu state from the View layer.
///
/// In-memory track data is managed in MadTunesViewModel.
@Observable
@MainActor
final class AlbumTableViewModel {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var mainVM: MadTunesViewModel?

  // MARK: - Dedicated Properties

  /// Table view: anchor for Shift+Click/Arrow range selection.
  var tableSelectionAnchorID: UUID?
  /// Table view: moving cursor (highlighted row).
  var tableSelectionCursorID: UUID?
  /// Phase 42: Set during keyboard navigation to auto-scroll the table.
  /// Not set on mouse click; reset to nil after the scroll completes.
  var tableScrollTargetID: UUID?

  // MARK: - Display Buffer

  /// Progressively-populated display buffer (Phase 56).
  /// Views should bind to this instead of the raw tracks array.
  var displayedTracks: [Track] = []

  // MARK: - Column Visibility

  /// Per-column visibility (persisted to UserDefaults).
  var tableColumnVisibility: [String: Bool] = {
    guard let data = UserDefaults.standard.data(forKey: TableColumnType.userDefaultsKey),
          let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else {
      return [:]
    }
    return dict
  }()

  /// Per-column widths (persisted to UserDefaults).
  var columnWidths: [String: CGFloat] = {
    guard let data = UserDefaults.standard.data(forKey: TableColumnType.columnWidthsKey),
          let dict = try? JSONDecoder().decode([String: CGFloat].self, from: data) else {
      return [:]
    }
    return dict
  }()

  // MARK: - Context Menu / Sheet State

  var isTrackInfoPresented = false
  var tracksForTrackInfo: [Track] = []
  var detailedMetadataList: [DetailedTrackMetadata?] = []

  var showDeleteConfirmation = false
  var tracksToDelete: [Track] = []

  var showNewPlaylistAlert = false
  var newPlaylistName = ""
  var trackIDsForNewPlaylist: Set<UUID> = []

  /// Phase 44: Table view column sorting (column type, ascending?)
  var tableSortCriteria: (column: TableColumnType, ascending: Bool)?

  /// Returns visible columns in display order.
  /// Playing indicator is always first and always visible.
  var visibleColumns: [TableColumnType] {
    let userVisible = TableColumnType.allCases.filter {
      $0 != .playingIndicator && isColumnVisible($0)
    }
    return [.playingIndicator] + (userVisible.isEmpty ? [.name] : userVisible)
  }

  /// Flat track list for table view (filtered + table-sorted).
  /// Replaces the old `currentTracks` / `currentTracks(fromAlbums:)`.
  var currentTracksDisplayed: [Track] {
    guard let mainVM else { return [] }
    let tracks = mainVM.filteredTracksBase
    guard let criteria = tableSortCriteria else { return tracks }
    return sortedTracks(tracks, by: criteria)
  }

  /// Whether the currently selected playlist supports drag‑reordering.
  ///
  /// Enabled for user static playlists and Favorites, disabled for All Music and
  /// any dynamic playlists. Also disabled when table sorting is active to avoid
  /// reordering a sorted view.
  var canReorderCurrentPlaylist: Bool {
    guard let mainVM else { return false }
    guard let playlistID = mainVM.selectedPlaylistID,
          let index = mainVM.library.playlists.firstIndex(where: { $0.id == playlistID })
    else {
      return false
    }
    // All Music (index 0) should never be reorderable.
    if index == 0 { return false }

    let playlist = mainVM.library.playlists[index]
    let isFavorites = playlist.kind == .system && index == 1
    let isStatic = playlist.kind == .staticList
    // Don't allow reordering while the table is sorted or filtered, since the
    // visible order would not map cleanly back to the playlist order.
    let canReorder = (isFavorites || isStatic)
      && tableSortCriteria == nil
      && mainVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !mainVM.isColumnBrowserFiltering
    return canReorder
  }

  // MARK: - Phase 52: Menu command helpers for track reordering

  /// Whether the selected tracks can be moved up in the current playlist.
  var canMoveSelectedTracksUp: Bool {
    guard let mainVM else { return false }
    guard mainVM.useTableView, canReorderCurrentPlaylist, !mainVM.selectedTrackIDs.isEmpty else { return false }
    let tracks = currentTracksDisplayed
    let firstSelectedIdx = tracks.firstIndex { mainVM.selectedTrackIDs.contains($0.id) }
    return (firstSelectedIdx ?? 0) > 0
  }

  /// Whether the selected tracks can be moved down in the current playlist.
  var canMoveSelectedTracksDown: Bool {
    guard let mainVM else { return false }
    guard mainVM.useTableView, canReorderCurrentPlaylist, !mainVM.selectedTrackIDs.isEmpty else { return false }
    let tracks = currentTracksDisplayed
    let lastSelectedIdx = tracks.lastIndex { mainVM.selectedTrackIDs.contains($0.id) }
    return (lastSelectedIdx ?? tracks.count - 1) < tracks.count - 1
  }

  // MARK: - Table Sorting

  // Phase 44: Get sort indicator for column header
  func sortIndicator(for column: TableColumnType) -> String? {
    guard let criteria = tableSortCriteria, criteria.column == column else { return nil }
    return criteria.ascending ? " ▲" : " ▼"
  }

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

  // MARK: - Track In-Playlist Position Relocators

  func moveTracksInCurrentPlaylist(trackIDs: [UUID], toIndex: Int) {
    guard let mainVM else { return }
    guard canReorderCurrentPlaylist, let playlistID = mainVM.selectedPlaylistID else { return }
    mainVM.library.moveTracks(trackIDs, inPlaylist: playlistID, toIndex: toIndex)
  }

  /// Moves selected tracks one position up. Called by menu command (Option+↑).
  func moveSelectedTracksUp() {
    guard let mainVM else { return }
    let tracks = currentTracksDisplayed
    let orderedSelected = tracks.enumerated().filter { mainVM.selectedTrackIDs.contains($0.element.id) }
    guard let firstIdx = orderedSelected.first?.offset, firstIdx > 0 else { return }
    moveTracksInCurrentPlaylist(trackIDs: orderedSelected.map(\.element.id), toIndex: firstIdx - 1)
  }

  /// Moves selected tracks one position down. Called by menu command (Option+↓).
  func moveSelectedTracksDown() {
    guard let mainVM else { return }
    let tracks = currentTracksDisplayed
    let orderedSelected = tracks.enumerated().filter { mainVM.selectedTrackIDs.contains($0.element.id) }
    guard let lastIdx = orderedSelected.last?.offset, lastIdx < tracks.count - 1 else { return }
    moveTracksInCurrentPlaylist(trackIDs: orderedSelected.map(\.element.id), toIndex: lastIdx + 2)
  }

  // MARK: - Column Visibility Methods

  func isColumnVisible(_ column: TableColumnType) -> Bool {
    tableColumnVisibility[column.rawValue] ?? column.isDefaultVisible
  }

  func toggleColumnVisibility(_ column: TableColumnType) {
    let currentValue = isColumnVisible(column)
    var newVisibility = tableColumnVisibility
    newVisibility[column.rawValue] = !currentValue

    // At least one column must remain visible.
    let allHidden = TableColumnType.allCases.allSatisfy {
      !(newVisibility[$0.rawValue] ?? $0.isDefaultVisible)
    }
    if allHidden {
      newVisibility[TableColumnType.name.rawValue] = true
    }

    tableColumnVisibility = newVisibility
    if let data = try? JSONEncoder().encode(newVisibility) {
      UserDefaults.standard.set(data, forKey: TableColumnType.userDefaultsKey)
    }
  }

  // MARK: - Column Width Methods

  func columnWidth(for column: TableColumnType) -> CGFloat {
    columnWidths[column.rawValue] ?? column.defaultWidth
  }

  func handleColumnResize(column: TableColumnType, translation: CGFloat) {
    let key = column.rawValue
    let currentWidth = columnWidths[key] ?? column.defaultWidth
    let newWidth = max(40, currentWidth + translation)
    columnWidths[key] = newWidth
    persistColumnWidths()
  }

  func scheduleDisplayedTracksUpdate(to newTracks: [Track]) {
    displayedTracksUpdateTask?.cancel()

    let batchSize = 50
    let largeUpdateThreshold = 2_000 // Threshold to avoid one-shot full replace on huge lists.

    /// Fast path: compare IDs without allocating temporary arrays.
    func isSameTrackSequence(_ a: [Track], _ b: [Track]) -> Bool {
      guard a.count == b.count else { return false }
      for (aTrack, bTrack) in zip(a, b) where aTrack.id != bTrack.id {
        return false
      }
      return true
    }

    /// Fast path: checks if `prefix` is a prefix of `full` by comparing IDs.
    func hasPrefixTrackIDs(prefix: [Track], full: [Track]) -> Bool {
      guard prefix.count <= full.count else { return false }
      for (aTrack, bTrack) in zip(prefix, full) where aTrack.id != bTrack.id {
        return false
      }
      return true
    }

    func appendInBatches(_ tracks: [Track]) async {
      var idx = 0
      while idx < tracks.count {
        if Task.isCancelled { return }
        let end = min(idx + batchSize, tracks.count)
        displayedTracks.append(contentsOf: tracks[idx ..< end])
        idx = end
        await Task.yield()
      }
    }

    displayedTracksUpdateTask = Task { @MainActor in
      // Fast reject: identical sequence.
      if isSameTrackSequence(newTracks, displayedTracks) { return }

      // Huge list update: avoid a single massive replacement that causes a UI freeze.
      if newTracks.count > largeUpdateThreshold {
        displayedTracks.removeAll()
        await appendInBatches(newTracks)
        return
      }

      // Empty → large: progressive append.
      if displayedTracks.isEmpty, newTracks.count > batchSize {
        displayedTracks.removeAll()
        await appendInBatches(newTracks)
        return
      }

      // Append-only: new list starts with old list.
      if hasPrefixTrackIDs(prefix: displayedTracks, full: newTracks) {
        let startIndex = displayedTracks.count
        var idx = startIndex
        while idx < newTracks.count {
          if Task.isCancelled { return }
          let end = min(idx + batchSize, newTracks.count)
          displayedTracks.append(contentsOf: newTracks[idx ..< end])
          idx = end
          await Task.yield()
        }
        return
      }

      // Fallback: full replace.
      displayedTracks = newTracks
    }
  }

  // MARK: - New Playlist Commit

  func commitNewPlaylistAlert(library: any MusicLibraryProviding) {
    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    let existingNames = Set(library.playlists.dropFirst(2).map(\.name))
    guard !existingNames.contains(name) else { return }
    library.addPlaylist(name: name)
    if let newPlaylist = library.playlists.last {
      library.addTracks(trackIDsForNewPlaylist, toPlaylist: newPlaylist.id)
    }
    trackIDsForNewPlaylist = []
  }

  // MARK: - Phase 63: Keyboard Navigation (moved from MadTunesViewModel)

  /// Handles keyboard input when the table view is active.
  /// Arrow keys, Shift+Arrow, PgUp/PgDn are handled natively by the List.
  /// Track reorder (Option+↑/↓) is handled via menu commands.
  /// This handler intercepts: Cmd+C copy, Cmd+↓/Return/Space to play.
  func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
    guard let mainVM else { return .ignored }
    let tracks = currentTracksDisplayed
    guard !tracks.isEmpty else { return .ignored }

    // CMD+C: Copy selected tracks metadata.
    if press.characters == "c", press.modifiers.contains(.command) {
      if !mainVM.selectedTrackIDs.isEmpty {
        mainVM.copySelectedTracksMetadata()
        return .handled
      }
    }

    // CMD+↓: Play selected tracks immediately.
    if press.key == .downArrow, press.modifiers.contains(.command) {
      let selected = tracks.filter { mainVM.selectedTrackIDs.contains($0.id) }
      if !selected.isEmpty {
        mainVM.player.setQueue(selected, startingAt: 0)
        return .handled
      }
      return .handled
    }

    // Return / Space: play selected tracks (or track at cursor).
    if press.key == .return || press.characters == " " {
      if press.characters == " ", mainVM.player.currentTrack != nil {
        mainVM.player.togglePlayPause()
        return .handled
      }
      let selected = tracks.filter { mainVM.selectedTrackIDs.contains($0.id) }
      if !selected.isEmpty {
        mainVM.player.setQueue(selected, startingAt: 0)
        return .handled
      }
      return .ignored
    }

    return .ignored
  }

  // MARK: Private

  // MARK: - Display Buffer Methods

  /// Coalesced/batched update (Phase 56). Progressively appends tracks
  /// in batches to keep the UI responsive during large imports.
  private var displayedTracksUpdateTask: Task<Void, Never>?

  private func persistColumnWidths() {
    if let data = try? JSONEncoder().encode(columnWidths) {
      UserDefaults.standard.set(data, forKey: TableColumnType.columnWidthsKey)
    }
  }
}
