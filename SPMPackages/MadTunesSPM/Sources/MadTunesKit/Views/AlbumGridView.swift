// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumGridView

/// iTunes 11-style album grid. Clicking an album expands a detail pane below that row.
struct AlbumGridView: View {
  let albums: [Album]
  @Binding var expandedAlbumID: UUID?
  @Binding var highlightedAlbumIDs: Set<UUID>
  @Binding var selectedTrackIDs: Set<UUID>
  var currentTrackID: UUID?
  let onTrackSelected: (Track, [Track]) -> Void
  var onAlbumDoubleClicked: ((Album) -> Void)?

  private let minItemWidth: CGFloat = 160
  private let spacing: CGFloat = 16

  @State private var screenVM: ScreenVM = .shared
  @State private var expandedAlbumWasInView = false

  private var canvasWidth: CGFloat {
    screenVM.mainColumnCanvasSizeObserved.width
  }

  private var columnCount: Int {
    max(1, Int((canvasWidth - spacing) / (minItemWidth + spacing)))
  }

  var body: some View {
    let rows = albums.chunked(into: columnCount)

    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: spacing) {
          ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            albumRow(row, columnCount: columnCount)

            // Expanded detail for the expanded album (if it belongs to this row).
            if let expandedAlbum = row.first(where: { $0.id == expandedAlbumID }) {
              ExpandedAlbumView(
                album: expandedAlbum,
                currentTrackID: currentTrackID,
                containerWidth: canvasWidth,
                selectedTrackIDs: $selectedTrackIDs,
                onTrackSelected: onTrackSelected,
                onClose: { withAnimation { expandedAlbumID = nil } }
              )
              .id("\(expandedAlbum.id)_\(Int(canvasWidth))")
              .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
              .onAppear { expandedAlbumWasInView = true }
              .onDisappear { expandedAlbumWasInView = false }
            }
          }
        }
        .padding(spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .onChange(of: expandedAlbumID) { _, newValue in
        guard let newValue else { return }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(100))
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("\(newValue)_\(Int(canvasWidth))")
          }
        }
      }
      .onChange(of: canvasWidth) { oldWidth, newWidth in
        guard oldWidth != newWidth, let expandedID = expandedAlbumID else { return }
        let wasVisible = expandedAlbumWasInView
        guard wasVisible else { return }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(200))
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("\(expandedID)_\(Int(newWidth))")
          }
        }
      }
    }
    .animation(.easeOut(duration: 0.12), value: screenVM.mainColumnCanvasSizeObserved.width)
  }

  // MARK: - Row

  @ViewBuilder
  private func albumRow(_ row: [Album], columnCount: Int) -> some View {
    HStack(alignment: .top, spacing: spacing) {
      ForEach(row) { album in
        let isExpanded = album.id == expandedAlbumID
        let isSelected = highlightedAlbumIDs.contains(
          album.id
        )
        let isMultiSelection = isSelected && highlightedAlbumIDs.count > 1
        AlbumGridItemView(
          album: album,
          isExpanded: isExpanded,
          isSelected: isSelected,
          isMultipleSelection: isMultiSelection
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
          Task { @MainActor in
            // Double-clicking an already-expanded album should NOT collapse it.
            if expandedAlbumID != album.id {
              withAnimation(.easeInOut(duration: 0.3)) {
                handleTrackRowSelection(album: album)
              }
            } else {
              highlightedAlbumIDs = [album.id]
            }
          }
          Task { @MainActor in
            onAlbumDoubleClicked?(album)
          }
        }
        .onTapGesture(count: 1) {
          Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.3)) {
              handleTrackRowSelection(album: album)
            }
          }
        }
        .frame(maxWidth: .infinity)
      }
      // Invisible spacers to keep alignment when the row is not full.
      if row.count < columnCount {
        ForEach(0 ..< (columnCount - row.count), id: \.self) { _ in
          Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
        }
      }
    }
  }

  private func handleTrackRowSelection(album: Album) {
    if NSEvent.modifierFlags.contains(.command) {
      if highlightedAlbumIDs.contains(album.id) {
        highlightedAlbumIDs.remove(album.id)
      } else {
        highlightedAlbumIDs.insert(album.id)
      }
      if highlightedAlbumIDs.count != 1 {
        expandedAlbumID = nil
      } else if let only = highlightedAlbumIDs.first {
        expandedAlbumID = expandedAlbumID == only ? nil : only
      }
    } else {
      highlightedAlbumIDs = [album.id]
      expandedAlbumID = expandedAlbumID == album.id ? nil : album.id
    }
  }
}
