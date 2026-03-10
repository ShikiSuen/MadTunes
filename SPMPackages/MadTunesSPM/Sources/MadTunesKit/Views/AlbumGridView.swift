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

  @State private var vm: MadTunesViewModel = .shared
  @State private var screenVM: ScreenVM = .shared
  @State private var expandedAlbumWasInView = false

  // Rubber-band drag selection state (macOS only).
  @State private var dragOrigin: CGPoint?
  @State private var dragCurrent: CGPoint?
  @State private var albumFrames: [UUID: CGRect] = [:]

  private var canvasWidth: CGFloat {
    screenVM.mainColumnCanvasSizeObserved.width
  }

  private var columnCount: Int {
    max(1, Int((canvasWidth - spacing) / (minItemWidth + spacing)))
  }

  /// Whether rubber-band drag selection is allowed (no expanded album).
  private var isDragSelectionEnabled: Bool {
    expandedAlbumID == nil
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
              .drawingGroup()
              .id("\(expandedAlbum.id)_\(Int(canvasWidth))")
              .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
              .onAppear { expandedAlbumWasInView = true }
              .onDisappear { expandedAlbumWasInView = false }
            }
          }
        }
        .padding(spacing)
        .coordinateSpace(name: "albumGrid")
        .onPreferenceChange(AlbumFramePreferenceKey.self) { frames in
          albumFrames = frames
        }
        .background {
          rubberBandDragLayer
        }
        .overlay {
          rubberBandRectOverlay
        }
      }
      .frame(width: canvasWidth, alignment: .leading)
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
    .animation(canvasAnimation, value: canvasWidth)
    .opacity(screenVM.windowSizeEverObserved ? 1 : 0)
  }

  private var canvasAnimation: Animation {
    let duration: TimeInterval = screenVM.windowSizeEverObserved ? 0.12 : 0
    return .easeOut(duration: duration)
  }

  // MARK: - Rubber-Band Drag Layer (background — does not block taps on album items)

  @ViewBuilder private var rubberBandDragLayer: some View {
    #if canImport(AppKit) && !canImport(UIKit)
    if isDragSelectionEnabled {
      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 4, coordinateSpace: .named("albumGrid"))
            .onChanged { value in
              if dragOrigin == nil {
                dragOrigin = value.startLocation
              }
              dragCurrent = value.location
              updateDragSelection()
            }
            .onEnded { _ in
              dragOrigin = nil
              dragCurrent = nil
            }
        )
    }
    #endif
  }

  // MARK: - Rubber-Band Rect Overlay (visual only — not hit-testable)

  @ViewBuilder private var rubberBandRectOverlay: some View {
    #if canImport(AppKit) && !canImport(UIKit)
    if let rect = selectionRect {
      Rectangle()
        .fill(Color.accentColor.opacity(0.15))
        .overlay(
          Rectangle()
            .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
        )
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
    }
    #endif
  }

  /// The normalised selection rectangle from drag origin to current position.
  private var selectionRect: CGRect? {
    guard let origin = dragOrigin, let current = dragCurrent else { return nil }
    return CGRect(
      x: min(origin.x, current.x),
      y: min(origin.y, current.y),
      width: abs(current.x - origin.x),
      height: abs(current.y - origin.y)
    )
  }

  private func updateDragSelection() {
    guard let rect = selectionRect else { return }
    var selected = Set<UUID>()
    for (id, frame) in albumFrames {
      if rect.intersects(frame) {
        selected.insert(id)
      }
    }
    highlightedAlbumIDs = selected
    expandedAlbumID = nil
    if let first = albums.first(where: { selected.contains($0.id) }) {
      vm.albumSelectionFixedAnchorID = first.id
      vm.albumSelectionCursorID = first.id
    }
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
        .background(
          GeometryReader { geo in
            Color.clear.preference(
              key: AlbumFramePreferenceKey.self,
              value: [album.id: geo.frame(in: .named("albumGrid"))]
            )
          }
        )
        .contentShape(Rectangle())
        .animation(
          .easeOut(duration: 0.12),
          value: vm.library.artworkLoadingKeys.contains(
            vm.library.albumKey(title: album.title, artist: album.artist)
          )
        )
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
    #if canImport(AppKit) && !canImport(UIKit)
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
    vm.albumSelectionFixedAnchorID = album.id
    vm.albumSelectionCursorID = album.id
    #else
    highlightedAlbumIDs = [album.id]
    expandedAlbumID = expandedAlbumID == album.id ? nil : album.id
    #endif
  }
}

// MARK: - AlbumFramePreferenceKey

private struct AlbumFramePreferenceKey: PreferenceKey {
  nonisolated(unsafe) static var defaultValue: [UUID: CGRect] = [:]

  static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}
