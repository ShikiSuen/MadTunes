// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import Observation

// MARK: - AlbumTableViewModel

/// Phase 60: Sub-ViewModel for AlbumTableView.
/// Extracts column visibility/width persistence, display buffering,
/// and context-menu state from the View layer.
@Observable
@MainActor
final class AlbumTableViewModel {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var mainVM: MadTunesViewModel?

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

  /// Returns visible columns in display order.
  /// Playing indicator is always first and always visible.
  var visibleColumns: [TableColumnType] {
    let userVisible = TableColumnType.allCases.filter {
      $0 != .playingIndicator && isColumnVisible($0)
    }
    return [.playingIndicator] + (userVisible.isEmpty ? [.name] : userVisible)
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

  // MARK: - Display Buffer Methods

  /// Coalesced/batched update (Phase 56). Progressively appends tracks
  /// in batches to keep the UI responsive during large imports.
  func scheduleDisplayedTracksUpdate(to newTracks: [Track]) {
    let batchSize = 50
    Task { @MainActor in
      if newTracks.map(\.id) == displayedTracks.map(\.id) { return }

      // Empty → large: progressive append.
      if displayedTracks.isEmpty, newTracks.count > batchSize {
        displayedTracks.removeAll()
        var idx = 0
        while idx < newTracks.count {
          let end = min(idx + batchSize, newTracks.count)
          displayedTracks.append(contentsOf: newTracks[idx ..< end])
          idx = end
          await Task.yield()
        }
        return
      }

      // Append-only: new list starts with old list.
      let oldIDs = displayedTracks.map(\.id)
      let newIDs = newTracks.map(\.id)
      if oldIDs.count <= newIDs.count, Array(newIDs.prefix(oldIDs.count)) == oldIDs {
        var idx = oldIDs.count
        while idx < newIDs.count {
          let end = min(idx + batchSize, newIDs.count)
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

  // MARK: Private

  private func persistColumnWidths() {
    if let data = try? JSONEncoder().encode(columnWidths) {
      UserDefaults.standard.set(data, forKey: TableColumnType.columnWidthsKey)
    }
  }
}
