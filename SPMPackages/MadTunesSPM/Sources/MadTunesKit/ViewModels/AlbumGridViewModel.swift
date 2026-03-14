// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

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
  /// Accesses shared state via mainVM directly (no inout).
  func handleAlbumSelection(album: Album) {
    guard let mainVM else { return }
    #if canImport(AppKit) && !canImport(UIKit)
    let flags = NSEvent.modifierFlags

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
    #else
    assignExpandedAlbumID(
      mainVM.expandedAlbumID == album.id ? nil : album.id
    )
    mainVM.highlightedAlbumIDs = [album.id]
    #endif
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

  // MARK: Private

  // MARK: - Display Buffer Methods

  /// In-flight batch update task. Cancelled on new updates.
  private var displayedAlbumsUpdateTask: Task<Void, Never>?

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
