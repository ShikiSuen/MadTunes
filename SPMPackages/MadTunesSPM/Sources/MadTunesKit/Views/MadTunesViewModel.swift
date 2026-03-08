// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - MadTunesViewModel

@Observable
@MainActor
final class MadTunesViewModel {
  // MARK: Internal

  var library = MusicLibrary()
  var player = AudioPlayer()
  var selectedPlaylistID: UUID?
  var expandedAlbumID: UUID?
  var highlightedAlbumIDs: Set<UUID> = []
  var selectedTrackIDs: Set<UUID> = []
  var isFileImporterPresented = false
  var isDropTargeted = false
  var albumSortOrder: AlbumSortOrder = .artistYearTitle
  var screenVM = ScreenVM.shared

  var gridColumnCount: Int {
    let width = screenVM.mainColumnCanvasSizeObserved.width
    return max(1, Int((width - gridSpacing) / (minItemWidth + gridSpacing)))
  }

  // MARK: - Computed Helpers

  var currentAlbums: [Album] {
    let unsorted: [Album]
    if let playlistID = selectedPlaylistID,
       let playlist = library.playlists.first(where: { $0.id == playlistID }),
       playlist.id != library.playlists.first?.id {
      unsorted = library.albums(for: playlist)
    } else {
      unsorted = library.albums
    }
    return sortedAlbums(unsorted)
  }

  var currentTrackArtwork: Data? {
    guard let track = player.currentTrack else { return nil }
    let key = library.albumKey(title: track.albumTitle, artist: track.albumArtist)
    return library.artworkCache[key]
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
    let tracks = album.sortedTracks
    guard tracks.first != nil else { return }
    player.setQueue(tracks, startingAt: 0)
    highlightedAlbumIDs = [album.id]
  }

  func importURLs(_ urls: [URL]) {
    Task { await library.importFiles(urls: urls) }
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
          #if os(macOS)
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
              #if os(macOS)
              if let scopedURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
              ) {
                _ = scopedURL.startAccessingSecurityScopedResource()
                await self.library.importFiles(urls: [scopedURL])
                return
              }
              #endif
            }
            await self.library.importFiles(urls: [url])
          }
        }
      }
    }
    return found
  }

  // MARK: - Keyboard Navigation

  func handleKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    if let expandedID = expandedAlbumID,
       let album = albums.first(where: { $0.id == expandedID }) {
      let result = handleExpandedKeyPress(press, album: album, albums: albums)
      if result == .handled { return .handled }
    }
    if expandedAlbumID == nil {
      return handleGridKeyPress(press, albums: albums)
    }
    return .ignored
  }

  // MARK: Private

  private let minItemWidth: CGFloat = 160
  private let gridSpacing: CGFloat = 16

  private func handleGridKeyPress(_ press: KeyPress, albums: [Album]) -> KeyPress.Result {
    guard !albums.isEmpty else { return .ignored }

    let isArrowKey = press.key == .upArrow || press.key == .downArrow
      || press.key == .leftArrow || press.key == .rightArrow

    if isArrowKey {
      guard let hID = highlightedAlbumIDs.first,
            let idx = albums.firstIndex(where: { $0.id == hID }) else {
        highlightedAlbumIDs = [albums[0].id]
        return .handled
      }
      let newIdx: Int
      if press.key == .rightArrow {
        newIdx = min(idx + 1, albums.count - 1)
      } else if press.key == .leftArrow {
        newIdx = max(idx - 1, 0)
      } else if press.key == .downArrow {
        newIdx = min(idx + gridColumnCount, albums.count - 1)
      } else {
        newIdx = max(idx - gridColumnCount, 0)
      }
      highlightedAlbumIDs = [albums[newIdx].id]
      return .handled
    }

    if press.key == .return || press.characters == " "
      || (press.modifiers.contains(.command) && press.key == .downArrow) {
      if let hID = highlightedAlbumIDs.first, highlightedAlbumIDs.count == 1 {
        withAnimation(.easeInOut(duration: 0.3)) {
          expandedAlbumID = hID
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
    let sorted = album.sortedTracks

    if press.key == .escape
      || (press.modifiers.contains(.command) && press.key == .upArrow) {
      withAnimation(.easeInOut(duration: 0.3)) {
        expandedAlbumID = nil
      }
      return .handled
    }

    if press.key == .return || press.characters == " "
      || (press.modifiers.contains(.command) && press.key == .downArrow) {
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

    let isArrowKey = press.key == .upArrow || press.key == .downArrow
      || press.key == .leftArrow || press.key == .rightArrow
    if isArrowKey {
      if selectedTrackIDs.isEmpty {
        if press.key == .downArrow {
          if let first = sorted.first {
            selectedTrackIDs = [first.id]
          }
          return .handled
        }
        if press.key == .upArrow {
          withAnimation(.easeInOut(duration: 0.3)) {
            expandedAlbumID = nil
          }
          return .handled
        }
        return navigateAlbumFromExpanded(press, albums: albums)
      }

      guard let anchorID = selectedTrackIDs.first(where: { _ in true }),
            let anchorIdx = sorted.firstIndex(where: { $0.id == anchorID })
      else { return .handled }

      let maxRowsPerColumn = 7
      let columnCount = sorted.count > maxRowsPerColumn
        ? max(1, Int(ceil(Double(sorted.count) / Double(maxRowsPerColumn))))
        : 1
      let itemsPerColumn = Int(ceil(Double(sorted.count) / Double(columnCount)))

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
    if press.key == .rightArrow {
      newIdx = min(idx + 1, albums.count - 1)
    } else if press.key == .leftArrow {
      newIdx = max(idx - 1, 0)
    } else {
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
