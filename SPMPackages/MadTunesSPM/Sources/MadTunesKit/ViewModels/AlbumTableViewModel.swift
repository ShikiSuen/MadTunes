// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation
import SwiftUI

// MARK: - CompoundSortEntry

/// Phase 116: Codable entry for persisting compound sort criteria as JSON.
private struct CompoundSortEntry: Codable {
  let column: String
  let ascending: Bool
}

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

  init() {
    // Phase 109: Load persisted column state once at init to avoid
    // JSON decoding from @AppStorage on every read during scroll.
    if let raw = UserDefaults.standard.string(forKey: TableColumnType.columnWidthsKey),
       let dict = [String: CGFloat](rawValue: raw) {
      self._columnWidths = dict
    }
    if let raw = UserDefaults.standard.string(forKey: TableColumnType.userDefaultsKey),
       let dict = [String: Bool](rawValue: raw) {
      self._tableColumnVisibility = dict
    }
  }

  // MARK: Internal

  // MARK: - Phase 74: Page/Endpoint Navigation (public for menu commands)

  enum PageNavigationTarget { case pageUp, pageDown, home, end }

  weak var mainVM: MadTunesViewModel?

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

  // MARK: - Context Menu / Sheet State

  var isTrackInfoPresented = false
  var tracksForTrackInfo: [Track] = []
  var detailedMetadataList: [DetailedTrackMetadata?] = []

  var showDeleteConfirmation = false
  var tracksToDelete: [Track] = []

  var showNewPlaylistAlert = false
  var newPlaylistName = ""
  var trackIDsForNewPlaylist: Set<UUID> = []

  /// Phase 44 / Phase 114 / Phase 115: Table view column sorting criteria stack.
  /// Multi-element compound sort for dynamic playlists (All Music); not used for static playlists
  /// (which apply persistent sorts directly to the playlist track order).
  var tableSortCriteria: [(column: TableColumnType, ascending: Bool)] = []

  /// Phase 69: Whether iOS edit mode (multi-select) is active.
  var isEditModeActive = false

  var tableColumnVisibility: [String: Bool] {
    get { access(keyPath: \.tableColumnVisibility); return _tableColumnVisibility }
    set {
      withMutation(keyPath: \.tableColumnVisibility) {
        _tableColumnVisibility = newValue
        // Phase 109: Write-through to UserDefaults.
        UserDefaults.standard.set(newValue.rawValue, forKey: TableColumnType.userDefaultsKey)
      }
    }
  }

  var columnWidths: [String: CGFloat] {
    get { access(keyPath: \.columnWidths); return _columnWidths }
    set {
      withMutation(keyPath: \.columnWidths) {
        _columnWidths = newValue
        // Phase 109: Write-through to UserDefaults.
        UserDefaults.standard.set(newValue.rawValue, forKey: TableColumnType.columnWidthsKey)
      }
    }
  }

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
    guard !tableSortCriteria.isEmpty else { return tracks }
    return sortedTracks(tracks, by: tableSortCriteria)
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
      && tableSortCriteria.isEmpty
      && mainVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !mainVM.isColumnBrowserFiltering
    return canReorder
  }

  /// Phase 69: Whether the current playlist supports iOS edit mode (multi-select).
  /// Enabled for Favorites and user static playlists on non-AppKit platforms.
  ///
  /// Edit mode is mutually exclusive with table sorting: sorting reorders the
  /// displayed list and therefore cannot be mixed with manual multi-selection.
  var canEnterEditMode: Bool {
    guard !OS.isAppKit else { return false }
    guard tableSortCriteria.isEmpty else { return false }
    guard let mainVM else { return false }
    guard let playlistID = mainVM.selectedPlaylistID,
          let index = mainVM.library.playlists.firstIndex(where: { $0.id == playlistID })
    else {
      return false
    }
    if index == 0 { return false }
    let playlist = mainVM.library.playlists[index]
    let isFavorites = playlist.kind == .system && index == 1
    return isFavorites || playlist.kind == .staticList
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

  /// Phase 74: Estimated visible rows for page-based scrolling.
  var tablePageSize: Int {
    guard let mainVM else { return 20 }
    let canvasHeight = mainVM.screenVM.mainColumnCanvasSizeObserved.height
    // Row height is ~20pt content + insets; estimate ~24pt per row.
    return max(1, Int((canvasHeight - 80) / 24))
  }

  // MARK: - Table Sorting

  /// Phase 115: Whether the current playlist allows compound (multi-column) sorting.
  /// Enabled for All Music and dynamic playlists; disabled for Favorites and static playlists
  /// (which use persistent sorting instead).
  var isCompoundSortAllowed: Bool {
    guard let mainVM else { return false }
    guard let playlistID = mainVM.selectedPlaylistID,
          let index = mainVM.library.playlists.firstIndex(where: { $0.id == playlistID })
    else {
      return false
    }
    // All Music (index 0) supports compound sort.
    if index == 0 { return true }
    let playlist = mainVM.library.playlists[index]
    // Dynamic playlists support compound sort.
    if playlist.kind == .dynamicList { return true }
    // Favorites and static playlists use persistent sort, not compound.
    return false
  }

  /// Phase 115: Whether the current playlist is a static playlist (Favorites or user-created).
  /// Used to determine if column sorting should persist to the playlist track order.
  var isCurrentPlaylistStatic: Bool {
    guard let mainVM else { return false }
    guard let playlistID = mainVM.selectedPlaylistID,
          let index = mainVM.library.playlists.firstIndex(where: { $0.id == playlistID })
    else {
      return false
    }
    if index == 0 { return false }
    let playlist = mainVM.library.playlists[index]
    let isFavorites = playlist.kind == .system && index == 1
    return isFavorites || playlist.kind == .staticList
  }

  // MARK: - Phase 96: ViewModel-level Observations

  /// Called by MadTunesViewModel after mainVM is assigned.
  func setupObservations() {
    observeCurrentTracksChange()
  }

  // Phase 44 / Phase 114 / Phase 115 / Phase 116: Get sort indicator for column header.
  // Static playlists: shows ▲/▼ for the last persistent-sort column if track order is unchanged.
  // Dynamic playlists: shows priority subscript when compound sorting is active.
  func sortIndicator(for column: TableColumnType) -> String? {
    // Phase 116: Static playlists use persistent sort indicator.
    if isCurrentPlaylistStatic {
      guard column == lastPersistentSortColumn else { return nil }
      // Verify the playlist order hasn't been manually changed (drag-reorder).
      if let storedHash = lastPersistentSortTrackIDsHash,
         let mainVM, let playlistID = mainVM.selectedPlaylistID,
         let playlist = mainVM.library.playlists.first(where: { $0.id == playlistID }) {
        guard playlist.trackIDs.hashValue == storedHash else { return nil }
      } else {
        return nil
      }
      return lastPersistentSortAscending ? " ▲" : " ▼"
    }
    // Dynamic playlists: compound sort indicator.
    guard let idx = tableSortCriteria.firstIndex(where: { $0.column == column }) else { return nil }
    let arrow = tableSortCriteria[idx].ascending ? " ▲" : " ▼"
    if tableSortCriteria.count > 1 {
      let subscripts: [Character] = ["₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]
      let priority = idx < subscripts.count ? String(subscripts[idx]) : "\(idx + 1)"
      return arrow + priority
    }
    return arrow
  }

  // Phase 44 / Phase 115 / Phase 116: Clear sorting (switch back to album/playlist order)
  func clearTableSorting() {
    tableSortCriteria = []
    lastPersistentSortColumn = nil
    lastPersistentSortAscending = true
    lastPersistentSortTrackIDsHash = nil
  }

  // Phase 44 / Phase 115: Set or toggle column sort.
  // On dynamic playlists (incl. All Music): compound sort — new columns are prepended as primary.
  // On static playlists: persistent sort — physically reorders playlist trackIDs.
  func setTableSort(column: TableColumnType) {
    // Sorting and edit mode are mutually exclusive.
    isEditModeActive = false

    // Phase 115: Static playlists use persistent sort that commits to playlist order.
    if isCurrentPlaylistStatic {
      applyPersistentSort(column: column)
      return
    }

    let compound = isCompoundSortAllowed

    if let existingIdx = tableSortCriteria.firstIndex(where: { $0.column == column }) {
      if existingIdx == 0 {
        // Primary column: toggle direction.
        let newAscending = !tableSortCriteria[0].ascending
        if newAscending {
          // Third click on primary: remove it.
          if compound, tableSortCriteria.count * 1 > 1 {
            tableSortCriteria.removeFirst()
          } else {
            tableSortCriteria = []
          }
        } else {
          tableSortCriteria[0] = (column: column, ascending: newAscending)
        }
      } else {
        // Non-primary column in compound mode: promote to primary, keep direction.
        let entry = tableSortCriteria.remove(at: existingIdx)
        tableSortCriteria.insert(entry, at: 0)
      }
    } else {
      // New column.
      if compound {
        tableSortCriteria.insert((column: column, ascending: true), at: 0)
      } else {
        tableSortCriteria = [(column: column, ascending: true)]
      }
    }

    // Phase 116: Persist compound sort for dynamic playlists.
    persistCompoundSort()
  }

  /// Phase 114: Sorts tracks by an ordered list of criteria (compound sort).
  /// The first element is the primary sort key; subsequent elements break ties.
  func sortedTracks(_ tracks: [Track], by criteriaStack: [(column: TableColumnType, ascending: Bool)]) -> [Track] {
    guard !criteriaStack.isEmpty else { return tracks }
    return tracks.sorted { lhs, rhs in
      for criteria in criteriaStack {
        let order = compareTracks(lhs, rhs, by: criteria)
        if order != .orderedSame { return order == .orderedAscending }
      }
      return false
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

  // MARK: - Phase 91: Play Like Double-Click

  /// Queues ALL currently displayed tracks, starting from the first selected
  /// track's position — identical to double-clicking a row.
  func playSelectedAsDoubleClick() {
    guard let mainVM else { return }
    let tracks = currentTracksDisplayed
    guard !tracks.isEmpty else { return }
    let cursorID = tableSelectionCursorID ?? mainVM.selectedTrackIDs.first
    let startIndex: Int
    if let cursorID, let idx = tracks.firstIndex(where: { $0.id == cursorID }) {
      startIndex = idx
    } else {
      startIndex = 0
    }
    Task {
      await mainVM.player.setQueue(tracks, startingAt: startIndex)
    }
  }

  // MARK: - Phase 63: Keyboard Navigation (moved from MadTunesViewModel)

  /// Handles keyboard input when the table view is active.
  /// On UIKit, List does not automatically move selection with arrow keys.
  /// Track reorder (Option+↑/↓) is handled via menu commands.
  func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
    guard let mainVM else { return .ignored }
    let tracks = currentTracksDisplayed
    guard !tracks.isEmpty else { return .ignored }

    // Arrow keys (UIKit only): move selection up/down in the List.
    if !OS.isAppKit,
       press.key == .upArrow || press.key == .downArrow,
       !press.modifiers.contains(.command),
       !press.modifiers.contains(.option) {
      let direction = press.key == .upArrow ? -1 : 1
      return moveSelection(
        direction: direction,
        extend: press.modifiers.contains(.shift),
        tracks: tracks,
        mainVM: mainVM
      )
    }

    // Phase 89: Cmd+A to select all, Escape to clear selection.
    if press.characters == "a", press.modifiers.contains(.command) {
      mainVM.selectedTrackIDs = Set(tracks.map(\.id))
      return .handled
    }
    if press.key == .escape {
      mainVM.selectedTrackIDs = []
      tableSelectionAnchorID = nil
      tableSelectionCursorID = nil
      return .handled
    }

    // CMD+C: Copy selected tracks metadata.
    if press.characters == "c", press.modifiers.contains(.command) {
      if !mainVM.selectedTrackIDs.isEmpty {
        mainVM.copySelectedTracksMetadata()
        return .handled
      }
    }

    // Phase 91: CMD+↓ / Enter / Shift+Space: play like double-click
    // (queue ALL displayed tracks starting from cursor position).
    if press.key == .downArrow, press.modifiers.contains(.command) {
      playSelectedAsDoubleClick()
      return .handled
    }
    if press.key == .return, !press.modifiers.contains(.command) {
      playSelectedAsDoubleClick()
      return .handled
    }

    // Phase 91: Space alone = toggle play/pause;
    // Shift+Space = play like double-click.
    if press.characters == " " {
      if press.modifiers.contains(.shift) {
        playSelectedAsDoubleClick()
      } else {
        Task {
          await mainVM.player.togglePlayPause()
        }
      }
      return .handled
    }

    // Page/Home/End: UIKit List does not provide native navigation, so handle
    // via KeyPress or menu commands on non-AppKit platforms.
    if !OS.isAppKit, press.isPageKey || press.key == .home || press.key == .end {
      return handlePageOrEndpointKey(press, tracks: tracks, mainVM: mainVM)
    }

    return .ignored
  }

  /// Called from menu commands (macCatalyst) or .onKeyPress fallback (iPadOS).
  /// Menu commands bypass UICollectionView's key command interception.
  func navigateToPage(_ target: PageNavigationTarget, isShift: Bool) {
    guard let mainVM else { return }
    let tracks = currentTracksDisplayed
    guard !tracks.isEmpty else { return }

    let referenceID = tableSelectionCursorID ?? mainVM.selectedTrackIDs.first
    let refIdx = referenceID.flatMap { id in tracks.firstIndex(where: { $0.id == id }) }

    let targetIdx: Int
    switch target {
    case .home: targetIdx = 0
    case .end: targetIdx = tracks.count - 1
    case .pageUp: targetIdx = max((refIdx ?? 0) - tablePageSize, 0)
    case .pageDown: targetIdx = min((refIdx ?? 0) + tablePageSize, tracks.count - 1)
    }

    let targetID = tracks[targetIdx].id

    if isShift {
      let anchorID: UUID
      if let existing = tableSelectionAnchorID {
        anchorID = existing
      } else if let first = mainVM.selectedTrackIDs.first,
                tracks.contains(where: { $0.id == first }) {
        anchorID = first
        tableSelectionAnchorID = anchorID
      } else {
        anchorID = targetID
        tableSelectionAnchorID = anchorID
      }
      if let anchorIdx = tracks.firstIndex(where: { $0.id == anchorID }) {
        let lo = min(anchorIdx, targetIdx)
        let hi = max(anchorIdx, targetIdx)
        mainVM.selectedTrackIDs = Set(tracks[lo ... hi].map(\.id))
      }
    } else {
      mainVM.selectedTrackIDs = [targetID]
      tableSelectionAnchorID = targetID
    }
    tableSelectionCursorID = targetID
    tableScrollTargetID = targetID
  }

  /// Moves the selection cursor up/down within the currently displayed track list.
  ///
  /// On UIKit platforms, `List` does not automatically move the selection using
  /// the hardware arrow keys, so we synthesize the expected behavior here.
  @discardableResult
  func moveSelection(
    direction: Int,
    extend: Bool,
    tracks: [Track],
    mainVM: MadTunesViewModel
  )
    -> KeyPress.Result {
    let currentID = tableSelectionCursorID ?? mainVM.selectedTrackIDs.first
    let currentIdx = currentID.flatMap { id in tracks.firstIndex(where: { $0.id == id }) } ?? 0
    let newIdx = max(0, min(tracks.count - 1, currentIdx + direction))
    guard newIdx != currentIdx || mainVM.selectedTrackIDs.isEmpty else { return .handled }
    let targetID = tracks[newIdx].id

    if extend {
      if tableSelectionAnchorID == nil {
        tableSelectionAnchorID = currentID ?? targetID
      }
      if let anchorID = tableSelectionAnchorID,
         let anchorIdx = tracks.firstIndex(where: { $0.id == anchorID }) {
        let lo = min(anchorIdx, newIdx)
        let hi = max(anchorIdx, newIdx)
        mainVM.selectedTrackIDs = Set(tracks[lo ... hi].map(\.id))
      }
    } else {
      mainVM.selectedTrackIDs = [targetID]
      tableSelectionAnchorID = targetID
    }
    tableSelectionCursorID = targetID
    tableScrollTargetID = targetID
    return .handled
  }

  /// Phase 116: Load persisted compound sort criteria for the current dynamic playlist.
  /// Called after playlist switch to restore the saved sort state.
  func loadCompoundSortForCurrentPlaylist() {
    guard let mainVM, let playlistID = mainVM.selectedPlaylistID,
          let index = mainVM.library.playlists.firstIndex(where: { $0.id == playlistID })
    else { return }

    let data: Data?
    if index == 0 {
      data = UserDefaults.standard.data(forKey: Self.allMusicCompoundSortKey)
    } else if mainVM.library.playlists[index].kind == .dynamicList {
      let d = mainVM.library.playlists[index].compoundSortData
      data = d.isEmpty ? nil : d
    } else {
      return
    }

    guard let data, let entries = try? JSONDecoder().decode([CompoundSortEntry].self, from: data) else { return }
    tableSortCriteria = entries.compactMap { entry in
      guard let column = TableColumnType(rawValue: entry.column) else { return nil }
      return (column: column, ascending: entry.ascending)
    }
  }

  // MARK: Private

  /// Phase 116: UserDefaults key for All Music compound sort persistence.
  private static let allMusicCompoundSortKey = "MadTunes.allMusicCompoundSort"

  // MARK: - Column Visibility

  /// Per-column visibility (persisted to UserDefaults).
  /// Phase 109: Plain stored property; loaded at init, write-through on set.
  /// Replaces @AppStorage to eliminate JSON decoding on every read.
  @ObservationIgnored private var _tableColumnVisibility: [String: Bool] = [:]

  /// Per-column widths (persisted to UserDefaults).
  /// Phase 109: Plain stored property; loaded at init, write-through on set.
  /// Replaces @AppStorage to eliminate JSON decoding on every read.
  @ObservationIgnored private var _columnWidths: [String: CGFloat] = [:]

  /// Phase 115: Tracks the last persistent sort column for toggle direction on static playlists.
  private var lastPersistentSortColumn: TableColumnType?
  private var lastPersistentSortAscending = true
  /// Phase 116: hashValue of trackIDs after persistent sort, for sort indicator validation.
  /// Cleared on playlist switch or when the user manually drag-reorders.
  private var lastPersistentSortTrackIDsHash: Int?

  // MARK: - Display Buffer Methods

  /// Coalesced/batched update (Phase 56). Progressively appends tracks
  /// in batches to keep the UI responsive during large imports.
  private var displayedTracksUpdateTask: Task<Void, Never>?

  /// Phase 115: Sort the current static playlist's tracks by column and persist the new order.
  /// Clicking the same column toggles ascending/descending; clicking a different column sorts ascending.
  private func applyPersistentSort(column: TableColumnType) {
    guard let mainVM else { return }
    guard let playlistID = mainVM.selectedPlaylistID else { return }

    // Determine sort direction: toggle if same column, ascending for new column.
    let ascending: Bool
    if lastPersistentSortColumn == column {
      ascending = !lastPersistentSortAscending
    } else {
      ascending = true
    }

    // Get current tracks in playlist order, sort them, extract new ID order.
    let tracks = mainVM.filteredTracksBase
    let sorted = sortedTracks(tracks, by: [(column: column, ascending: ascending)])
    let newTrackIDs = sorted.map(\.id)

    // Commit to persistence.
    mainVM.library.reorderPlaylistTracks(playlistID: playlistID, newTrackIDs: newTrackIDs)

    // Update tracking state for toggle direction and sort indicator validation.
    lastPersistentSortColumn = column
    lastPersistentSortAscending = ascending
    lastPersistentSortTrackIDsHash = newTrackIDs.hashValue
  }

  /// Phase 116: Persist the current compound sort criteria for the active dynamic playlist.
  /// All Music: saves to UserDefaults. Other dynamic playlists: saves to SwiftData via library.
  private func persistCompoundSort() {
    guard let mainVM, let playlistID = mainVM.selectedPlaylistID,
          let index = mainVM.library.playlists.firstIndex(where: { $0.id == playlistID })
    else { return }

    let entries = tableSortCriteria.map {
      CompoundSortEntry(column: $0.column.rawValue, ascending: $0.ascending)
    }

    if index == 0 {
      // All Music: persist to UserDefaults.
      if entries.isEmpty {
        UserDefaults.standard.removeObject(forKey: Self.allMusicCompoundSortKey)
      } else if let data = try? JSONEncoder().encode(entries) {
        UserDefaults.standard.set(data, forKey: Self.allMusicCompoundSortKey)
      }
    } else if mainVM.library.playlists[index].kind == .dynamicList {
      // Dynamic playlist: persist to SwiftData.
      let data = (try? JSONEncoder().encode(entries)) ?? Data()
      mainVM.library.updateCompoundSortData(playlistID: playlistID, data: data)
    }
  }

  /// Compares two tracks by a single sort criterion.
  private func compareTracks(
    _ lhs: Track, _ rhs: Track,
    by criteria: (column: TableColumnType, ascending: Bool)
  )
    -> ComparisonResult {
    let ascending = criteria.ascending
    let raw: ComparisonResult
    switch criteria.column {
    case .name:
      raw = lhs.title.localizedStandardCompare(rhs.title)
    case .length:
      raw = lhs.duration < rhs.duration ? .orderedAscending
        : lhs.duration > rhs.duration ? .orderedDescending : .orderedSame
    case .artist:
      raw = lhs.artist.localizedStandardCompare(rhs.artist)
    case .albumTitle:
      raw = lhs.albumTitle.localizedStandardCompare(rhs.albumTitle)
    case .albumArtist:
      raw = lhs.albumArtist.localizedStandardCompare(rhs.albumArtist)
    case .trackNumber:
      let disc: ComparisonResult = lhs.discNumber == rhs.discNumber ? .orderedSame
        : lhs.discNumber < rhs.discNumber ? .orderedAscending : .orderedDescending
      if disc != .orderedSame {
        raw = disc
      } else if lhs.trackNumber < rhs.trackNumber {
        raw = .orderedAscending
      } else if lhs.trackNumber > rhs.trackNumber {
        raw = .orderedDescending
      } else {
        raw = .orderedSame
      }
    case .genre:
      raw = lhs.genre.localizedStandardCompare(rhs.genre)
    case .year:
      let y0 = lhs.year ?? Int.min, y1 = rhs.year ?? Int.min
      raw = y0 < y1 ? .orderedAscending : y0 > y1 ? .orderedDescending : .orderedSame
    case .folder:
      raw = lhs.folderPath.localizedStandardCompare(rhs.folderPath)
    case .fileExtension:
      raw = lhs.fileExtension.localizedStandardCompare(rhs.fileExtension)
    case .playingIndicator:
      raw = lhs.title.localizedStandardCompare(rhs.title)
    }
    if !ascending {
      switch raw {
      case .orderedAscending: return .orderedDescending
      case .orderedDescending: return .orderedAscending
      case .orderedSame: return .orderedSame
      }
    }
    return raw
  }

  // MARK: - Phase 96: Private Observations

  /// Phase 96: Track `currentTracksDisplayed` changes and update display buffer.
  private func observeCurrentTracksChange() {
    withObservationTracking {
      _ = self.currentTracksDisplayed
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.scheduleDisplayedTracksUpdate(to: self.currentTracksDisplayed)
        self.observeCurrentTracksChange()
      }
    }
  }

  /// Phase 74: PgUp/PgDn/Home/End handler.
  private func handlePageOrEndpointKey(
    _ press: KeyPress, tracks: [Track], mainVM: MadTunesViewModel
  )
    -> KeyPress.Result {
    let target: PageNavigationTarget
    switch press.key {
    case .home: target = .home
    case .end: target = .end
    case .pageUp: target = .pageUp
    case .pageDown: target = .pageDown
    default: return .ignored
    }
    navigateToPage(target, isShift: press.modifiers.contains(.shift))
    return .handled
  }
}
