// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation
import SwiftUI

// MARK: - AlbumGridViewModel

/// Phase 60: Sub-ViewModel for AlbumGridView.
/// Extracts display buffering, selection logic, drag state,
/// and context-menu state from the View layer.
///
/// This model also serves the purposes of managing in-memory Album data.
@Observable
@MainActor
final class AlbumGridViewModel {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  weak var mainVM: MadTunesViewModel?

  // MARK: - Dedicated Properties (Stored)

  var albumSortOrder: AlbumSortOrder = .artistYearTitle

  var expandedAlbumID: UUID?
  var displayedAlbumsCache: [Album] = []
  var highlightedAlbumIDs: Set<UUID> = []
  /// The fixed anchor for Shift+Arrow range selection. Set on click / plain arrow.
  var albumSelectionFixedAnchorID: UUID?
  /// The moving cursor for Shift+Arrow range selection.
  var albumSelectionCursorID: UUID?
  // Scroll-to-album trigger (set by artwork double-click, consumed by AlbumGridView)
  var scrollToAlbumID: UUID?

  // MARK: - Display Buffer

  /// Progressively-populated display buffer (Phase 56).
  var displayedAlbums: [Album] = []

  // MARK: - Drag Selection State (macOS rubber-band)

  var dragOrigin: CGPoint?
  var dragCurrent: CGPoint?
  var albumFrames: [UUID: CGRect] = [:]
  var expandedAlbumFrame: CGRect?
  var preDragHighlighted: Set<UUID> = []

  // MARK: - Context Menu / Sheet State

  var isTrackInfoPresented = false
  var tracksForTrackInfo: [Track] = []
  var detailedMetadataList: [DetailedTrackMetadata?] = []

  var showDeleteConfirmation = false
  var albumsToDelete: [Album] = []

  var showNewPlaylistAlert = false
  var newPlaylistName = ""
  var trackIDsForNewPlaylist: Set<UUID> = []

  // MARK: - Debouncers

  /// Phase 49: Single debouncer for album click handling.
  let albumClickDebouncer: Debouncer = .init(delay: 0.25)

  /// Phase 54: Unify the management of the delay of proxy-scroll action.
  let proxyScrollDebouncer: Debouncer = .init(delay: 0.3)

  // MARK: - Expansion tracking

  var expandedAlbumWasInView = false

  // MARK: - Phase 98: Intel Mac Performance Mode

  /// Phase 98: Whether to use safeAreaInset-based expansion (Intel Mac performance mode).
  /// @AppStorage + @ObservationIgnored bridge for @Observable compatibility.
  var legacyHardwareMode: Bool {
    get { access(keyPath: \.legacyHardwareMode); return _legacyHardwareMode }
    set { withMutation(keyPath: \.legacyHardwareMode) { _legacyHardwareMode = newValue } }
  }

  // MARK: - Dedicated Properties (Computed)

  var gridColumnCount: Int {
    guard let mainVM else { return 1 }
    let width = mainVM.screenVM.mainColumnCanvasSizeObserved.width
    return max(1, Int((width - gridSpacing) / (minItemWidth + gridSpacing)))
  }

  /// Number of albums to scroll per page (PgUp/PgDown).
  /// Estimates visible rows based on screen height and item dimensions.
  var gridPageSize: Int {
    guard let mainVM else { return 10 }
    let canvasHeight = mainVM.screenVM.mainColumnCanvasSizeObserved.height
    // Approximate item height: scaled artwork (160 * 0.92) + text area (~50) + padding
    let approximateRowHeight: CGFloat = 160 + 50 + gridSpacing
    let visibleRows = max(1, Int((canvasHeight - 100) / approximateRowHeight)) // 100 for player controls
    return visibleRows * gridColumnCount
  }

  /// Albums for grid view, derived from filtered tracks.
  /// Each album contains ONLY the tracks that passed all filters.
  /// Replaces the old `currentAlbums`.
  var currentAlbumsDisplayed: [Album] {
    guard let mainVM else { return [] }
    let tokens = searchTokens(from: mainVM.searchText)
    // When search is active and cache is ready, use cached albums.
    if !tokens.isEmpty, !displayedAlbumsCache.isEmpty || mainVM.isSearching {
      return displayedAlbumsCache
    }

    return buildAlbumsFromFilteredTracks(
      mainVM.filteredTracksBase
    )
  }

  /// Albums from the current playlist, before column browser filtering.
  var unfilteredAlbums: [Album] {
    guard let mainVM else { return [] }
    if let playlistID = mainVM.selectedPlaylistID,
       let playlist = mainVM.library.playlists.first(
         where: { $0.id == playlistID }
       ),
       playlist.id != mainVM.library.playlists.first?.id {
      return mainVM.library.albums(for: playlist)
    }
    return mainVM.library.albums
  }

  // MARK: - Selection Rect

  /// The normalised selection rectangle from drag origin to current position.
  var selectionRect: CGRect? {
    guard let origin = dragOrigin, let current = dragCurrent else { return nil }
    return CGRect(
      x: min(origin.x, current.x),
      y: min(origin.y, current.y),
      width: abs(current.x - origin.x),
      height: abs(current.y - origin.y)
    )
  }

  // MARK: - Phase 96: ViewModel-level Observations

  /// Called by MadTunesViewModel after mainVM is assigned.
  func setupObservations() {
    observeCurrentAlbumsChange()
  }

  // MARK: - DoubleClick Handlers

  func onTrackDoubleClicked(_ track: Track, albumTracks: [Track]) {
    guard let mainVM else { return }
    Task {
      await mainVM.player.setQueue(
        albumTracks,
        startingAt: albumTracks.firstIndex(of: track) ?? 0
      )
    }
  }

  func onAlbumDoubleClicked(_ album: Album) {
    guard let mainVM else { return }
    // Album passed here is already filtered (contains only matching tracks).
    let tracks = album.tracks
    guard !tracks.isEmpty else { return }
    Task {
      await mainVM.player.setQueue(tracks, startingAt: 0)
    }
    highlightedAlbumIDs = [album.id]
  }

  /// Coalesced/batched update (Phase 56). Progressively appends albums
  /// in batches to keep the grid responsive during large imports.
  func scheduleDisplayedAlbumsUpdate(to newAlbums: [Album], ensureVisibleAlbumID: UUID? = nil) {
    displayedAlbumsUpdateTask?.cancel()
    displayedAlbumsUpdateTask = Task { @MainActor in
      let batchSize = 30
      let largeUpdateThreshold = 2_000

      func isSameIDSequence(_ a: [Album], _ b: [Album]) -> Bool {
        // Phase 130: Album.== now includes allTrackIDsSet, so Array.==
        // correctly detects both ID and track-content changes.
        a == b
      }

      func hasPrefixIDs(prefix: [Album], full: [Album]) -> Bool {
        // Phase 130: Use strict less-than so equal-length arrays with
        // different track contents always fall through to the replacement
        // path (isSameIDSequence already handles the truly-identical case).
        guard prefix.count < full.count else { return false }
        for (aAlbum, bAlbum) in zip(prefix, full) where aAlbum != bAlbum {
          return false
        }
        return true
      }

      @MainActor
      func appendInBatches(
        _ albums: [Album],
        startingAt startIndex: Int = 0,
        ensureVisibleIndex: Int? = nil
      ) async {
        var idx = startIndex
        while idx < albums.count {
          if Task.isCancelled { return }

          let currentBatchSize: Int
          if let targetIndex = ensureVisibleIndex, idx <= targetIndex {
            // Increase batch size when we still need to reach target index.
            currentBatchSize = min(
              largeUpdateThreshold,
              max(batchSize, targetIndex - idx + 1)
            )
          } else {
            currentBatchSize = batchSize
          }

          let end = min(idx + currentBatchSize, albums.count)
          displayedAlbums.append(contentsOf: albums[idx ..< end])
          idx = end
          await Task.yield()
        }
      }

      // No-op if identical by id sequence.
      if isSameIDSequence(displayedAlbums, newAlbums) {
        displayedAlbumsUpdateTask = nil
        return
      }

      // If we need a specific album to be visible quickly, ensure it is included
      // in the first batch by prefixing enough albums to contain it.
      if let targetID = ensureVisibleAlbumID,
         !displayedAlbums.contains(where: { $0.id == targetID }),
         let targetIndex = newAlbums.firstIndex(where: { $0.id == targetID }) {
        let initialCount = min(
          newAlbums.count,
          max(batchSize, targetIndex + 1)
        )
        displayedAlbums = Array(newAlbums.prefix(initialCount))

        // Continue appending the rest (if any) while still ensuring we progress
        // toward the full dataset.
        if initialCount < newAlbums.count {
          await appendInBatches(newAlbums, startingAt: initialCount, ensureVisibleIndex: targetIndex)
        }

        displayedAlbumsUpdateTask = nil
        return
      }

      // Large update: avoid single-shot replace to prevent UI freeze.
      if newAlbums.count > largeUpdateThreshold {
        displayedAlbums.removeAll()
        await appendInBatches(newAlbums)
        displayedAlbumsUpdateTask = nil
        return
      }

      // Initial large load: progressive append.
      if displayedAlbums.isEmpty, newAlbums.count > batchSize {
        displayedAlbums.removeAll()
        await appendInBatches(newAlbums)
        displayedAlbumsUpdateTask = nil
        return
      }

      // Append-only fast path.
      if hasPrefixIDs(prefix: displayedAlbums, full: newAlbums) {
        await appendInBatches(newAlbums, startingAt: displayedAlbums.count)
        displayedAlbumsUpdateTask = nil
        return
      }

      // Fallback: replace entirely.
      displayedAlbums = newAlbums
      displayedAlbumsUpdateTask = nil
    }
  }

  // MARK: - Drag Selection

  /// Phase 62: Update highlighted albums based on current rubber-band rect.
  /// Accesses shared state via mainVM directly (no inout).
  func updateDragSelection() {
    guard mainVM != nil, let rect = selectionRect else { return }
    var selected = preDragHighlighted
    for (id, frame) in albumFrames {
      if rect.intersects(frame) {
        selected.insert(id)
      }
    }
    highlightedAlbumIDs = selected
    expandedAlbumID = nil
    if let first = displayedAlbums.first(where: { selected.contains($0.id) }) {
      albumSelectionFixedAnchorID = first.id
      albumSelectionCursorID = first.id
    }
  }

  // MARK: - Album Selection

  /// Phase 62: Handle album click with modifier key awareness (Phase 36).
  /// Phase 63: Uses SwiftUI EventModifiers via mainVM instead of NSEvent.
  func handleAlbumSelection(album: Album) {
    guard let mainVM else { return }
    let flags = mainVM.currentModifiers

    if flags.contains(.shift) {
      handleShiftClick(album: album)
    } else if flags.contains(.command) {
      if highlightedAlbumIDs.contains(album.id) {
        highlightedAlbumIDs.remove(album.id)
      } else {
        highlightedAlbumIDs.insert(album.id)
      }
      if highlightedAlbumIDs.count != 1 {
        assignExpandedAlbumID(nil)
      } else if let only = highlightedAlbumIDs.first {
        assignExpandedAlbumID(
          expandedAlbumID == only ? nil : only
        )
      }
      albumSelectionFixedAnchorID = album.id
      albumSelectionCursorID = album.id
    } else {
      assignExpandedAlbumID(
        expandedAlbumID == album.id ? nil : album.id
      )
      highlightedAlbumIDs = [album.id]
      albumSelectionFixedAnchorID = album.id
      albumSelectionCursorID = album.id
    }
  }

  /// Phase 36/62: Shift+click range selection (Windows Explorer style).
  func handleShiftClick(album: Album) {
    guard mainVM != nil else { return }
    let currentAlbums = displayedAlbums

    let anchorID: UUID
    if let existingAnchor = albumSelectionFixedAnchorID {
      anchorID = existingAnchor
    } else if let first = highlightedAlbumIDs.first {
      anchorID = first
      albumSelectionFixedAnchorID = anchorID
    } else {
      highlightedAlbumIDs = [album.id]
      albumSelectionFixedAnchorID = album.id
      albumSelectionCursorID = album.id
      expandedAlbumID = nil
      return
    }

    guard let anchorIdx = currentAlbums.firstIndex(where: { $0.id == anchorID }),
          let clickIdx = currentAlbums.firstIndex(where: { $0.id == album.id }) else {
      highlightedAlbumIDs = [album.id]
      albumSelectionFixedAnchorID = album.id
      albumSelectionCursorID = album.id
      expandedAlbumID = nil
      return
    }

    let lo = min(anchorIdx, clickIdx)
    let hi = max(anchorIdx, clickIdx)
    highlightedAlbumIDs = Set(currentAlbums[lo ... hi].map(\.id))
    albumSelectionCursorID = album.id
    expandedAlbumID = nil
  }

  // MARK: - Show Track Info

  func showTrackInfo(for selectedAlbums: [Album]) {
    tracksForTrackInfo = selectedAlbums.flatMap(\.tracks)
    Task {
      var metadataList: [DetailedTrackMetadata?] = []
      for track in tracksForTrackInfo {
        let metadata = await MetadataReader.readDetailedMetadata(from: track.fileURL)
        metadataList.append(metadata)
      }
      detailedMetadataList = metadataList
      isTrackInfoPresented = true
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

  /// Main keyboard dispatcher for grid mode.
  func handleKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    guard let mainVM else { return .ignored }

    // CMD+A: Select All
    if press.characters == "a", press.modifiers.contains(.command) {
      if let expandedID = expandedAlbumID,
         let album = albums.first(where: { $0.id == expandedID }) {
        mainVM.selectAllVisibleTracks(in: album)
      } else {
        mainVM.selectAllVisibleAlbums()
      }
      return .handled
    }

    // CMD+C: Copy selected tracks metadata (only when album expanded and tracks selected)
    if press.characters == "c", press.modifiers.contains(.command) {
      if expandedAlbumID != nil, !mainVM.selectedTrackIDs.isEmpty {
        mainVM.copySelectedTracksMetadata()
        return .handled
      }
    }

    // Spacebar: prioritise toggling play/pause when a track is loaded,
    // but only when an album is expanded.
    spaceTask: if press.characters == " " {
      let hasAlbumExpanded = expandedAlbumID != nil
      switch press.modifiers {
      case [] where mainVM.player.currentTrack != nil && hasAlbumExpanded:
        Task {
          await mainVM.player.togglePlayPause()
        }
        return .handled
      case [.shift] where !(mainVM.player.currentTrack != nil && hasAlbumExpanded):
        Task {
          await mainVM.player.togglePlayPause()
        }
        return .handled
      default: break spaceTask
      }
    }

    switch albums.first(where: { $0.id == expandedAlbumID }) {
    case .none:
      return handleGridKeyPress(press, albums: albums)
    case let .some(album):
      let result = handleExpandedKeyPress(press, album: album, albums: albums)
      if result == .handled { return .handled }
    }

    return .ignored
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

  // MARK: Private

  // MARK: - Display Buffer Methods

  @ObservationIgnored @AppStorage(
    wrappedValue: ThisDevice.isIntelProcessor,
    "MadTunes.AlbumGridViewIntelMacCompatibility"
  ) private var _legacyHardwareMode

  private let minItemWidth: CGFloat = 160
  private let gridSpacing: CGFloat = 16

  /// In-flight batch update task. Cancelled on new updates.
  private var displayedAlbumsUpdateTask: Task<Void, Never>?

  // MARK: - Phase 96: Private Observations

  /// Phase 96: Track `currentAlbumsDisplayed` changes and update display buffer.
  private func observeCurrentAlbumsChange() {
    withObservationTracking {
      _ = self.currentAlbumsDisplayed
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.scheduleDisplayedAlbumsUpdate(to: self.currentAlbumsDisplayed)
        self.observeCurrentAlbumsChange()
      }
    }
  }

  // MARK: - Computed Helpers

  /// Groups a flat filtered track list back into Album objects, preserving
  /// original album metadata (id) via `unfilteredAlbums`.
  private func buildAlbumsFromFilteredTracks(_ filteredTracks: [Track]) -> [Album] {
    let filteredIDs = Set(filteredTracks.map(\.id))
    let albums = unfilteredAlbums.compactMap { album -> Album? in
      let matching = album.tracks.filter { filteredIDs.contains($0.id) }
      guard !matching.isEmpty else { return nil }
      // Phase 111: Use presorted init — filtered tracks retain album's existing sort order.
      return Album(
        id: album.id,
        title: album.title,
        artist: album.artist,
        presortedTracks: matching
      )
    }
    return sortedAlbums(albums)
  }

  // MARK: Private – Keyboard Navigation

  private func handleGridKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    guard mainVM != nil, !albums.isEmpty else { return .ignored }

    handleArrowKey: if press.isArrowKey {
      let isShift = press.modifiers.contains(.shift)

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
        let anchorID: UUID
        if let existing = albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = highlightedAlbumIDs.first {
          anchorID = first
          albumSelectionFixedAnchorID = anchorID
        } else {
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

      if newIdx != idx {
        scrollToAlbumID = albums[newIdx].id
      }

      return .handled
    }

    handlePageKey: if press.isPageKey {
      let isShift = press.modifiers.contains(.shift)
      let pageDelta = gridPageSize
      guard pageDelta > 0 else { break handlePageKey }

      let referenceID: UUID? = albumSelectionCursorID ?? highlightedAlbumIDs.first

      guard let hID = referenceID,
            let idx = albums.firstIndex(where: { $0.id == hID }) else {
        let isPageDown = press.key == .pageDown
        let targetIdx = isPageDown ? min(pageDelta, albums.count - 1) : 0
        let targetID = albums[targetIdx].id
        highlightedAlbumIDs = [targetID]
        albumSelectionFixedAnchorID = targetID
        albumSelectionCursorID = targetID
        scrollToAlbumID = targetID
        return .handled
      }

      let isPageDown = press.key == .pageDown
      let newIdx: Int
      if isPageDown {
        newIdx = min(idx + pageDelta, albums.count - 1)
      } else {
        newIdx = max(idx - pageDelta, 0)
      }

      if isShift {
        let anchorID: UUID
        if let existing = albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = highlightedAlbumIDs.first {
          anchorID = first
          albumSelectionFixedAnchorID = anchorID
        } else {
          anchorID = albums[idx].id
          albumSelectionFixedAnchorID = anchorID
        }

        guard let anchorIdx = albums.firstIndex(where: { $0.id == anchorID }) else {
          return .handled
        }

        albumSelectionCursorID = albums[newIdx].id

        let lo = min(anchorIdx, newIdx)
        let hi = max(anchorIdx, newIdx)
        highlightedAlbumIDs = Set(albums[lo ... hi].map(\.id))
        expandedAlbumID = nil
      } else {
        let newID = albums[newIdx].id
        highlightedAlbumIDs = [newID]
        albumSelectionFixedAnchorID = newID
        albumSelectionCursorID = newID
      }

      scrollToAlbumID = albums[newIdx].id
      return .handled
    }

    // Phase 74: Home / End — jump to first / last album.
    handleHomeEndKey: if press.key == .home || press.key == .end {
      let isShift = press.modifiers.contains(.shift)
      let targetIdx = press.key == .home ? 0 : albums.count - 1
      let targetID = albums[targetIdx].id

      if isShift {
        let anchorID: UUID
        if let existing = albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = highlightedAlbumIDs.first {
          anchorID = first
          albumSelectionFixedAnchorID = anchorID
        } else {
          highlightedAlbumIDs = [targetID]
          albumSelectionFixedAnchorID = targetID
          albumSelectionCursorID = targetID
          scrollToAlbumID = targetID
          break handleHomeEndKey
        }

        guard let anchorIdx = albums.firstIndex(where: { $0.id == anchorID }) else {
          break handleHomeEndKey
        }

        albumSelectionCursorID = targetID
        let lo = min(anchorIdx, targetIdx)
        let hi = max(anchorIdx, targetIdx)
        highlightedAlbumIDs = Set(albums[lo ... hi].map(\.id))
        expandedAlbumID = nil
      } else {
        highlightedAlbumIDs = [targetID]
        albumSelectionFixedAnchorID = targetID
        albumSelectionCursorID = targetID
      }
      scrollToAlbumID = targetID
      return .handled
    }

    if press.isAlbumExpansionAssignmentKey {
      if highlightedAlbumIDs.count == 1 {
        withAnimation(.interactiveSpring.nerf(legacyHardwareMode)) {
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
    guard let mainVM else { return .ignored }
    let sorted = album.tracks
    guard !sorted.isEmpty else {
      if press.key == .escape || (press.modifiers.contains(.command) && press.key == .upArrow) {
        withAnimation(.interactiveSpring.nerf(legacyHardwareMode)) { expandedAlbumID = nil }
        return .handled
      }
      return .ignored
    }

    if press.key == .escape
      || (press.modifiers.contains(.command) && press.key == .upArrow) {
      withAnimation(.interactiveSpring.nerf(legacyHardwareMode)) {
        expandedAlbumID = nil
      }
      return .handled
    }

    if press.isAlbumExpansionAssignmentKey {
      let selectedSorted = sorted.filter { mainVM.selectedTrackIDs.contains($0.id) }
      if !selectedSorted.isEmpty {
        Task {
          await mainVM.player.setQueue(selectedSorted, startingAt: 0)
        }
        return .handled
      }
      withAnimation(.interactiveSpring.nerf(legacyHardwareMode)) {
        expandedAlbumID = nil
      }
      return .handled
    }

    if press.isArrowKey {
      if mainVM.selectedTrackIDs.isEmpty {
        switch press.key {
        case .downArrow:
          if let first = sorted.first {
            mainVM.selectedTrackIDs = [first.id]
          }
          return .handled
        case .upArrow:
          withAnimation(.interactiveSpring.nerf(legacyHardwareMode)) {
            expandedAlbumID = nil
          }
          return .handled
        default:
          return navigateAlbumFromExpanded(press, albums: albums)
        }
      }

      guard let anchorID = mainVM.selectedTrackIDs.first(where: { _ in true })
      else { return .handled }

      let maxRowsPerColumn = 7
      let factor = mainVM.uiFactor * mainVM.uiFactor
      let minColumnWidth: CGFloat = 300 * factor
      let containerWidth = mainVM.screenVM.mainColumnCanvasSizeObserved.width
      let trackListWidth = Swift.max(minColumnWidth, containerWidth - 292 * factor)
      let maxPossibleColumns = Swift.max(1, Int(trackListWidth / minColumnWidth))
      let desiredColumns = sorted.count > maxRowsPerColumn ? maxPossibleColumns : 1
      let columnCount = Swift.max(1, Swift.min(sorted.count, desiredColumns))
      let itemsPerColumn = sorted.isEmpty ? 0 : Int(ceil(Double(sorted.count) / Double(columnCount)))

      // Phase 127: Support Shift+Arrow range selection in ExpandedAlbumView.
      // List View layout: items fill column top-to-bottom, then next column.
      // - Up/Down: move within same column (index ±1)
      // - Left/Right: move to adjacent column at same row (index ±itemsPerColumn)
      let isShift = press.modifiers.contains(.shift)

      // Determine cursor position (the moving end of selection)
      let cursorID = mainVM.trackSelectionCursorID ?? anchorID
      guard let cursorIdx = sorted.firstIndex(where: { $0.id == cursorID })
      else { return .handled }

      // Calculate new cursor position based on arrow key
      let newIdx: Int
      switch press.key {
      case .upArrow:
        newIdx = max(cursorIdx - 1, 0)
      case .downArrow:
        newIdx = min(cursorIdx + 1, sorted.count - 1)
      case .rightArrow:
        newIdx = min(cursorIdx + itemsPerColumn, sorted.count - 1)
      case .leftArrow:
        newIdx = max(cursorIdx - itemsPerColumn, 0)
      default:
        return .handled
      }

      if isShift {
        // Shift+Arrow: range selection
        // Initialize anchor if not set (use cursor position as initial anchor)
        if mainVM.trackSelectionAnchorID == nil {
          mainVM.trackSelectionAnchorID = cursorID
        }
        guard let anchorIDForRange = mainVM.trackSelectionAnchorID,
              let anchorIdxForRange = sorted.firstIndex(where: { $0.id == anchorIDForRange })
        else { return .handled }

        // Select range from anchor to new cursor position
        let range = min(anchorIdxForRange, newIdx) ... max(anchorIdxForRange, newIdx)
        mainVM.selectedTrackIDs = Set(sorted[range].map(\.id))
        mainVM.trackSelectionCursorID = sorted[newIdx].id
        // Anchor stays fixed during Shift+Arrow
      } else {
        // Plain Arrow: single selection, anchor and cursor both move
        mainVM.selectedTrackIDs = [sorted[newIdx].id]
        mainVM.trackSelectionAnchorID = sorted[newIdx].id
        mainVM.trackSelectionCursorID = sorted[newIdx].id
      }
      return .handled
    }

    return .ignored
  }

  private func navigateAlbumFromExpanded(
    _ press: KeyPress, albums: [Album]
  )
    -> KeyPress.Result {
    guard mainVM != nil,
          let hID = highlightedAlbumIDs.first ?? expandedAlbumID,
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
    withAnimation(.interactiveSpring.nerf(legacyHardwareMode)) {
      highlightedAlbumIDs = [newAlbumID]
      expandedAlbumID = newAlbumID
    }
    return .handled
  }

  /// Phase 62: Assign expandedAlbumID via mainVM with a short delay.
  /// The 50ms delay lets the double-click's second tap arrive before
  /// the layout shifts from expansion, complementing Phase 61's debouncer.
  private func assignExpandedAlbumID(_ newID: UUID?) {
    guard mainVM != nil, expandedAlbumID != newID else { return }
    Task {
      try? await Task.sleep(for: .milliseconds(50))
      expandedAlbumID = newID
      // Phase 111: Clear stale frame when closing expanded album.
      if newID == nil { expandedAlbumFrame = nil }
    }
  }
}

// MARK: - KeyPress Helpers (Phase 63: moved from MadTunesViewModel)

extension KeyPress {
  var isArrowKey: Bool {
    [.upArrow, .downArrow, .leftArrow, .rightArrow].contains(key)
  }

  var isPageKey: Bool {
    key == .pageUp || key == .pageDown
  }

  var isAlbumExpansionAssignmentKey: Bool {
    switch key {
    case .return: return true
    case .downArrow: return modifiers.contains(.command)
    default: return characters == " "
    }
  }
}
