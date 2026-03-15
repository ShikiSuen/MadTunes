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
@Observable
@MainActor
final class AlbumGridViewModel {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var mainVM: MadTunesViewModel?

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

  /// Coalesced/batched update (Phase 56). Progressively appends albums
  /// in batches to keep the grid responsive during large imports.
  func scheduleDisplayedAlbumsUpdate(to newAlbums: [Album], ensureVisibleAlbumID: UUID? = nil) {
    displayedAlbumsUpdateTask?.cancel()
    displayedAlbumsUpdateTask = Task { @MainActor in
      let batchSize = 30

      // Fast path: ensure immediate visibility of a target album.
      if ensureVisibleAlbumID != nil {
        displayedAlbums = newAlbums
        displayedAlbumsUpdateTask = nil
        return
      }

      // No-op if identical by id sequence.
      let newIDs = newAlbums.map(\.id)
      if displayedAlbums.map(\.id) == newIDs { displayedAlbumsUpdateTask = nil; return }

      // Initial large load: progressive append.
      if displayedAlbums.isEmpty, newAlbums.count > batchSize {
        displayedAlbums.removeAll()
        var idx = 0
        while idx < newAlbums.count {
          if Task.isCancelled { displayedAlbumsUpdateTask = nil; return }
          let end = min(idx + batchSize, newAlbums.count)
          displayedAlbums.append(contentsOf: newAlbums[idx ..< end])
          idx = end
          await Task.yield()
        }
        displayedAlbumsUpdateTask = nil
        return
      }

      // Append-only fast path.
      let oldIDs = displayedAlbums.map(\.id)
      if oldIDs.count <= newIDs.count, Array(newIDs.prefix(oldIDs.count)) == oldIDs {
        var idx = oldIDs.count
        while idx < newIDs.count {
          if Task.isCancelled { displayedAlbumsUpdateTask = nil; return }
          let end = min(idx + batchSize, newIDs.count)
          displayedAlbums.append(contentsOf: newAlbums[idx ..< end])
          idx = end
          await Task.yield()
        }
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
    guard let mainVM, let rect = selectionRect else { return }
    var selected = preDragHighlighted
    for (id, frame) in albumFrames {
      if rect.intersects(frame) {
        selected.insert(id)
      }
    }
    mainVM.highlightedAlbumIDs = selected
    mainVM.expandedAlbumID = nil
    if let first = displayedAlbums.first(where: { selected.contains($0.id) }) {
      mainVM.albumSelectionFixedAnchorID = first.id
      mainVM.albumSelectionCursorID = first.id
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
      if mainVM.highlightedAlbumIDs.contains(album.id) {
        mainVM.highlightedAlbumIDs.remove(album.id)
      } else {
        mainVM.highlightedAlbumIDs.insert(album.id)
      }
      if mainVM.highlightedAlbumIDs.count != 1 {
        assignExpandedAlbumID(nil)
      } else if let only = mainVM.highlightedAlbumIDs.first {
        assignExpandedAlbumID(
          mainVM.expandedAlbumID == only ? nil : only
        )
      }
      mainVM.albumSelectionFixedAnchorID = album.id
      mainVM.albumSelectionCursorID = album.id
    } else {
      assignExpandedAlbumID(
        mainVM.expandedAlbumID == album.id ? nil : album.id
      )
      mainVM.highlightedAlbumIDs = [album.id]
      mainVM.albumSelectionFixedAnchorID = album.id
      mainVM.albumSelectionCursorID = album.id
    }
  }

  /// Phase 36/62: Shift+click range selection (Windows Explorer style).
  func handleShiftClick(album: Album) {
    guard let mainVM else { return }
    let currentAlbums = displayedAlbums

    let anchorID: UUID
    if let existingAnchor = mainVM.albumSelectionFixedAnchorID {
      anchorID = existingAnchor
    } else if let first = mainVM.highlightedAlbumIDs.first {
      anchorID = first
      mainVM.albumSelectionFixedAnchorID = anchorID
    } else {
      mainVM.highlightedAlbumIDs = [album.id]
      mainVM.albumSelectionFixedAnchorID = album.id
      mainVM.albumSelectionCursorID = album.id
      mainVM.expandedAlbumID = nil
      return
    }

    guard let anchorIdx = currentAlbums.firstIndex(where: { $0.id == anchorID }),
          let clickIdx = currentAlbums.firstIndex(where: { $0.id == album.id }) else {
      mainVM.highlightedAlbumIDs = [album.id]
      mainVM.albumSelectionFixedAnchorID = album.id
      mainVM.albumSelectionCursorID = album.id
      mainVM.expandedAlbumID = nil
      return
    }

    let lo = min(anchorIdx, clickIdx)
    let hi = max(anchorIdx, clickIdx)
    mainVM.highlightedAlbumIDs = Set(currentAlbums[lo ... hi].map(\.id))
    mainVM.albumSelectionCursorID = album.id
    mainVM.expandedAlbumID = nil
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
      if let expandedID = mainVM.expandedAlbumID,
         let album = albums.first(where: { $0.id == expandedID }) {
        mainVM.selectAllVisibleTracks(in: album)
      } else {
        mainVM.selectAllVisibleAlbums()
      }
      return .handled
    }

    // CMD+C: Copy selected tracks metadata (only when album expanded and tracks selected)
    if press.characters == "c", press.modifiers.contains(.command) {
      if mainVM.expandedAlbumID != nil, !mainVM.selectedTrackIDs.isEmpty {
        mainVM.copySelectedTracksMetadata()
        return .handled
      }
    }

    // Spacebar: prioritise toggling play/pause when a track is loaded,
    // but only when an album is expanded.
    spaceTask: if press.characters == " " {
      let hasAlbumExpanded = mainVM.expandedAlbumID != nil
      switch press.modifiers {
      case [] where mainVM.player.currentTrack != nil && hasAlbumExpanded:
        mainVM.player.togglePlayPause()
        return .handled
      case [.shift] where !(mainVM.player.currentTrack != nil && hasAlbumExpanded):
        mainVM.player.togglePlayPause()
        return .handled
      default: break spaceTask
      }
    }

    switch albums.first(where: { $0.id == mainVM.expandedAlbumID }) {
    case .none:
      return handleGridKeyPress(press, albums: albums)
    case let .some(album):
      let result = handleExpandedKeyPress(press, album: album, albums: albums)
      if result == .handled { return .handled }
    }

    return .ignored
  }

  // MARK: Private

  // MARK: - Display Buffer Methods

  /// In-flight batch update task. Cancelled on new updates.
  private var displayedAlbumsUpdateTask: Task<Void, Never>?

  // MARK: Private – Keyboard Navigation

  private func handleGridKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    guard let mainVM, !albums.isEmpty else { return .ignored }

    handleArrowKey: if press.isArrowKey {
      let isShift = press.modifiers.contains(.shift)

      let referenceID: UUID? = isShift
        ? (mainVM.albumSelectionCursorID ?? mainVM.highlightedAlbumIDs.first)
        : mainVM.highlightedAlbumIDs.first

      guard let hID = referenceID,
            let idx = albums.firstIndex(where: { $0.id == hID }) else {
        let firstID = albums[0].id
        mainVM.highlightedAlbumIDs = [firstID]
        mainVM.albumSelectionFixedAnchorID = firstID
        mainVM.albumSelectionCursorID = firstID
        return .handled
      }

      let newIdx: Int
      switch press.key {
      case .rightArrow:
        newIdx = min(idx + 1, albums.count - 1)
      case .leftArrow:
        newIdx = max(idx - 1, 0)
      case .downArrow:
        newIdx = min(idx + mainVM.gridColumnCount, albums.count - 1)
      case .upArrow:
        newIdx = max(idx - mainVM.gridColumnCount, 0)
      default:
        break handleArrowKey
      }

      if isShift {
        let anchorID: UUID
        if let existing = mainVM.albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = mainVM.highlightedAlbumIDs.first {
          anchorID = first
          mainVM.albumSelectionFixedAnchorID = anchorID
        } else {
          let newID = albums[newIdx].id
          mainVM.highlightedAlbumIDs = [newID]
          mainVM.albumSelectionFixedAnchorID = newID
          mainVM.albumSelectionCursorID = newID
          mainVM.expandedAlbumID = nil
          if newIdx != idx {
            mainVM.scrollToAlbumID = newID
          }
          return .handled
        }

        guard let anchorIdx = albums.firstIndex(where: { $0.id == anchorID }) else {
          return .handled
        }

        let cursorIdx = newIdx
        mainVM.albumSelectionCursorID = albums[cursorIdx].id

        let lo = min(anchorIdx, cursorIdx)
        let hi = max(anchorIdx, cursorIdx)
        mainVM.highlightedAlbumIDs = Set(albums[lo ... hi].map(\.id))
        mainVM.expandedAlbumID = nil
      } else {
        let newID = albums[newIdx].id
        mainVM.highlightedAlbumIDs = [newID]
        mainVM.albumSelectionFixedAnchorID = newID
        mainVM.albumSelectionCursorID = newID
      }

      if newIdx != idx {
        mainVM.scrollToAlbumID = albums[newIdx].id
      }

      return .handled
    }

    handlePageKey: if press.isPageKey {
      let isShift = press.modifiers.contains(.shift)
      let pageDelta = mainVM.gridPageSize
      guard pageDelta > 0 else { break handlePageKey }

      let referenceID: UUID? = mainVM.albumSelectionCursorID ?? mainVM.highlightedAlbumIDs.first

      guard let hID = referenceID,
            let idx = albums.firstIndex(where: { $0.id == hID }) else {
        let isPageDown = press.key == .pageDown
        let targetIdx = isPageDown ? min(pageDelta, albums.count - 1) : 0
        let targetID = albums[targetIdx].id
        mainVM.highlightedAlbumIDs = [targetID]
        mainVM.albumSelectionFixedAnchorID = targetID
        mainVM.albumSelectionCursorID = targetID
        mainVM.scrollToAlbumID = targetID
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
        if let existing = mainVM.albumSelectionFixedAnchorID {
          anchorID = existing
        } else if let first = mainVM.highlightedAlbumIDs.first {
          anchorID = first
          mainVM.albumSelectionFixedAnchorID = anchorID
        } else {
          anchorID = albums[idx].id
          mainVM.albumSelectionFixedAnchorID = anchorID
        }

        guard let anchorIdx = albums.firstIndex(where: { $0.id == anchorID }) else {
          return .handled
        }

        mainVM.albumSelectionCursorID = albums[newIdx].id

        let lo = min(anchorIdx, newIdx)
        let hi = max(anchorIdx, newIdx)
        mainVM.highlightedAlbumIDs = Set(albums[lo ... hi].map(\.id))
        mainVM.expandedAlbumID = nil
      } else {
        let newID = albums[newIdx].id
        mainVM.highlightedAlbumIDs = [newID]
        mainVM.albumSelectionFixedAnchorID = newID
        mainVM.albumSelectionCursorID = newID
      }

      mainVM.scrollToAlbumID = albums[newIdx].id
      return .handled
    }

    if press.isAlbumExpansionAssignmentKey {
      if mainVM.highlightedAlbumIDs.count == 1 {
        withAnimation(.easeInOut(duration: 0.3)) {
          mainVM.expandedAlbumID = mainVM.highlightedAlbumIDs.first
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
        withAnimation(.easeInOut(duration: 0.3)) { mainVM.expandedAlbumID = nil }
        return .handled
      }
      return .ignored
    }

    if press.key == .escape
      || (press.modifiers.contains(.command) && press.key == .upArrow) {
      withAnimation(.easeInOut(duration: 0.3)) {
        mainVM.expandedAlbumID = nil
      }
      return .handled
    }

    if press.isAlbumExpansionAssignmentKey {
      let selectedSorted = sorted.filter { mainVM.selectedTrackIDs.contains($0.id) }
      if !selectedSorted.isEmpty {
        mainVM.player.setQueue(selectedSorted, startingAt: 0)
        return .handled
      }
      withAnimation(.easeInOut(duration: 0.3)) {
        mainVM.expandedAlbumID = nil
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
          withAnimation(.easeInOut(duration: 0.3)) {
            mainVM.expandedAlbumID = nil
          }
          return .handled
        default:
          return navigateAlbumFromExpanded(press, albums: albums)
        }
      }

      guard let anchorID = mainVM.selectedTrackIDs.first(where: { _ in true }),
            let anchorIdx = sorted.firstIndex(where: { $0.id == anchorID })
      else { return .handled }

      let maxRowsPerColumn = 7
      let trackListWidth = max(300, mainVM.screenVM.mainColumnCanvasSizeObserved.width - 292)
      let minColumnWidth: CGFloat = 300
      let maxPossibleColumns = max(1, Int(trackListWidth / minColumnWidth))
      let desiredColumns = sorted.count > maxRowsPerColumn ? maxPossibleColumns : 1
      let columnCount = max(1, min(sorted.count, desiredColumns))
      let itemsPerColumn = sorted.isEmpty ? 0 : Int(ceil(Double(sorted.count) / Double(columnCount)))

      switch press.key {
      case .upArrow:
        let firstIdx = sorted.firstIndex(where: { mainVM.selectedTrackIDs.contains($0.id) }) ?? anchorIdx
        if firstIdx == 0 {
          mainVM.selectedTrackIDs.removeAll()
        } else {
          mainVM.selectedTrackIDs = [sorted[firstIdx - 1].id]
        }
      case .downArrow:
        let lastIdx = sorted.lastIndex(where: { mainVM.selectedTrackIDs.contains($0.id) }) ?? anchorIdx
        if lastIdx >= sorted.count - 1 {
          withAnimation(.easeInOut(duration: 0.3)) {
            mainVM.expandedAlbumID = nil
          }
          mainVM.selectedTrackIDs.removeAll()
        } else {
          mainVM.selectedTrackIDs = [sorted[lastIdx + 1].id]
        }
      case .rightArrow:
        let newIdx = min(anchorIdx + itemsPerColumn, sorted.count - 1)
        mainVM.selectedTrackIDs = [sorted[newIdx].id]
      case .leftArrow:
        let newIdx = max(anchorIdx - itemsPerColumn, 0)
        mainVM.selectedTrackIDs = [sorted[newIdx].id]
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
    guard let mainVM,
          let hID = mainVM.highlightedAlbumIDs.first ?? mainVM.expandedAlbumID,
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
      newIdx = max(idx - mainVM.gridColumnCount, 0)
    }
    guard newIdx != idx else { return .handled }
    let newAlbumID = albums[newIdx].id
    withAnimation(.easeInOut(duration: 0.3)) {
      mainVM.highlightedAlbumIDs = [newAlbumID]
      mainVM.expandedAlbumID = newAlbumID
    }
    return .handled
  }

  /// Phase 62: Assign expandedAlbumID via mainVM with a short delay.
  /// The 50ms delay lets the double-click's second tap arrive before
  /// the layout shifts from expansion, complementing Phase 61's debouncer.
  private func assignExpandedAlbumID(_ newID: UUID?) {
    guard let mainVM, mainVM.expandedAlbumID != newID else { return }
    Task {
      try? await Task.sleep(for: .milliseconds(50))
      mainVM.expandedAlbumID = newID
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
