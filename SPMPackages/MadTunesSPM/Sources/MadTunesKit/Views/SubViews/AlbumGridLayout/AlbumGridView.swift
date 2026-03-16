// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumGridView

/// iTunes 11-style album grid. Clicking an album expands a detail pane below that row.
struct AlbumGridView: View {
  // MARK: Lifecycle

  /// Phase 62: Simplified init — shared state (expandedAlbumID,
  /// highlightedAlbumIDs, selectedTrackIDs) is read from vm directly.
  init() {}

  // MARK: Internal

  var body: some View {
    mainContent
      // Phase 54: Unify the animated response against `expandedAlbumID` changes.
      .animation(.easeInOut(duration: 0.3), value: gridVM.expandedAlbumID)
      .animation(canvasAnimation, value: canvasWidth)
      .opacity(screenVM.windowSizeEverObserved ? 1 : 0)
      .sheet(isPresented: Bindable(gridVM).isTrackInfoPresented) {
        trackInfoSheetContent
      }
      .alert(
        String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
        isPresented: Bindable(gridVM).showDeleteConfirmation
      ) {
        Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
        Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
          let trackIDs = Set(gridVM.albumsToDelete.flatMap { $0.tracks.map(\.id) })
          vm.removeTracksFromLibrary(trackIDs)
          gridVM.albumsToDelete = []
        }
      } message: {
        Text(String(
          localized: "i18n:Alert.RemoveAlbumsMessage",
          defaultValue: "This will remove \(gridVM.albumsToDelete.count) album(s) from the library. The original files will not be deleted.",
          bundle: #bundle
        ))
      }
      .alert(
        String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
        isPresented: Bindable(gridVM).showNewPlaylistAlert
      ) {
        TextField(
          String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
          text: Bindable(gridVM).newPlaylistName
        )
        Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
          gridVM.commitNewPlaylistAlert(library: vm.library)
        }
        Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      }
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared
  @State private var screenVM: ScreenVM = .shared

  private var spacing: CGFloat { 16 * vm.uiFactor }

  private var minItemWidth: CGFloat { 160 * vm.uiFactor }

  private var albums: [Album] {
    gridVM.currentAlbumsDisplayed
  }

  // Phase 53: Only show playing indicator when actively playing.
  private var currentTrackID: UUID? {
    vm.player.isPlaying ? vm.player.currentTrack?.id : nil
  }

  // Phase 60: Sub-ViewModel reference.
  private var gridVM: AlbumGridViewModel { vm.gridVM }

  private var canvasWidth: CGFloat {
    screenVM.mainColumnCanvasSizeObserved.width
  }

  private var columnCount: Int {
    max(1, Int((canvasWidth - spacing) / (minItemWidth + spacing)))
  }

  /// Whether rubber-band drag selection is allowed (no expanded album).
  private var isDragSelectionEnabled: Bool {
    gridVM.expandedAlbumID == nil
  }

  private var canvasAnimation: Animation {
    let duration: TimeInterval = screenVM.windowSizeEverObserved ? 0.12 : 0
    return .easeOut(duration: duration)
  }

  /// The normalised selection rectangle from drag origin to current position.
  private var selectionRect: CGRect? {
    gridVM.selectionRect
  }

  // MARK: - Content Views

  @ViewBuilder private var mainContent: some View {
    ScrollViewReader { proxy in
      let rows = gridVM.displayedAlbums.chunked(into: columnCount)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: spacing) {
          ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            albumRow(row, columnCount: columnCount)

            // Expanded detail for the expanded album (if it belongs to this row).
            if let expandedAlbum = row.first(where: { $0.id == gridVM.expandedAlbumID }) {
              ExpandedAlbumView(
                album: expandedAlbum,
                currentTrackID: currentTrackID,
                containerWidth: canvasWidth,
                selectedTrackIDs: Bindable(vm).selectedTrackIDs,
                onClose: { withAnimation(.easeInOut(duration: 0.3)) { gridVM.expandedAlbumID = nil } }
              )
              .drawingGroup()
              .id("\(expandedAlbum.id)_\(Int(canvasWidth))")
              .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
              .onAppear { gridVM.expandedAlbumWasInView = true }
              .onDisappear { gridVM.expandedAlbumWasInView = false }
            }
          }
        }
        .padding(spacing)
        .coordinateSpace(name: "albumGrid")
        .onPreferenceChange(AlbumFramePreferenceKey.self) { frames in
          gridVM.albumFrames = frames
        }
        .onPreferenceChange(ExpandedAlbumFramePreferenceKey.self) { frame in
          gridVM.expandedAlbumFrame = frame
        }
        .background {
          rubberBandDragLayer
        }
        .overlay {
          rubberBandRectOverlay
        }
      }
      .scrollContentBackground(.hidden)
      .frame(width: canvasWidth, alignment: .leading)
      .onAppear {
        gridVM.scheduleDisplayedAlbumsUpdate(to: albums)
      }
      .onChange(of: albums) { _, newAlbums in
        gridVM.scheduleDisplayedAlbumsUpdate(to: newAlbums)
      }
      .onChange(of: gridVM.expandedAlbumID) { _, newValue in
        guard let newValue else { return }
        // Ensure the expanded album is included in displayedAlbums quickly.
        gridVM.scheduleDisplayedAlbumsUpdate(to: albums, ensureVisibleAlbumID: newValue)
        gridVM.proxyScrollDebouncer.debounceOnMain {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("\(newValue)_\(Int(canvasWidth))")
          }
        }
      }
      .onChange(of: canvasWidth) { oldWidth, newWidth in
        guard oldWidth != newWidth, let expandedID = gridVM.expandedAlbumID else { return }
        let wasVisible = gridVM.expandedAlbumWasInView
        guard wasVisible else { return }
        gridVM.proxyScrollDebouncer.debounceOnMain {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("\(expandedID)_\(Int(newWidth))")
          }
        }
      }
      .onChange(of: gridVM.scrollToAlbumID) { _, newValue in
        guard let albumID = newValue else { return }
        gridVM.scrollToAlbumID = nil
        // If the target album isn't yet in displayedAlbums, ask for a quick
        // inclusion so that proxy.scrollTo can find the row.
        if !gridVM.displayedAlbums.contains(where: { $0.id == albumID }) {
          gridVM.scheduleDisplayedAlbumsUpdate(to: albums, ensureVisibleAlbumID: albumID)
        }
        // Compute the row offset using the full album list.
        let rows = albums.chunked(into: columnCount)
        guard let rowIndex = rows.firstIndex(
          where: { $0.contains { $0.id == albumID } }
        ) else { return }
        gridVM.proxyScrollDebouncer.debounceOnMain {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(rowIndex, anchor: .center)
          }
        }
      }
    }
  }

  @ViewBuilder private var trackInfoSheetContent: some View {
    if gridVM.tracksForTrackInfo.count == 1, let track = gridVM.tracksForTrackInfo.first {
      TrackInfoView(
        track: track,
        detailedMetadata: gridVM.detailedMetadataList.first ?? nil
      )
    } else {
      MultiTrackInfoView(
        tracks: gridVM.tracksForTrackInfo,
        detailedMetadataList: gridVM.detailedMetadataList
      )
    }
  }

  // MARK: - Rubber-Band Drag Layer (background — does not block taps on album items)

  @ViewBuilder private var rubberBandDragLayer: some View {
    // layer responsible for closing the expanded album when user clicks an empty
    // portion of the grid. Uses a drag gesture with zero minimum distance so that we
    // can inspect the final location and ignore true drags by checking translation.
    Color.clear
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .named("albumGrid"))
          .onEnded { value in
            // only treat as a tap if the user didn't actually drag
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            guard dx < 5, dy < 5 else { return }

            guard gridVM.expandedAlbumID != nil else { return }
            // if the tap is inside album artwork item or inside the expanded view,
            // ignore it rather than closing.
            if gridVM.albumFrames.values.contains(where: { $0.contains(value.location) }) {
              return
            }
            if let extFrame = gridVM.expandedAlbumFrame, extFrame.contains(value.location) {
              return
            }

            gridVM.expandedAlbumID = nil
          }
      )

    if isDragSelectionEnabled {
      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 4, coordinateSpace: .named("albumGrid"))
            .onChanged { value in
              if gridVM.dragOrigin == nil {
                gridVM.dragOrigin = value.startLocation
                // Phase 63: Use SwiftUI EventModifiers instead of NSEvent.
                if vm.currentModifiers.contains(.command) {
                  gridVM.preDragHighlighted = gridVM.highlightedAlbumIDs
                } else {
                  gridVM.preDragHighlighted = []
                }
              }
              gridVM.dragCurrent = value.location
              gridVM.updateDragSelection()
            }
            .onEnded { _ in
              gridVM.dragOrigin = nil
              gridVM.dragCurrent = nil
            }
        )
    }
  }

  // MARK: - Rubber-Band Rect Overlay (visual only — not hit-testable)

  @ViewBuilder private var rubberBandRectOverlay: some View {
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
  }

  // MARK: - Row

  @ViewBuilder
  private func albumRow(_ row: [Album], columnCount: Int) -> some View {
    HStack(alignment: .top, spacing: spacing) {
      ForEach(row) { album in
        let isExpanded = album.id == gridVM.expandedAlbumID
        let isSelected = gridVM.highlightedAlbumIDs.contains(
          album.id
        )
        let isCursor = gridVM.albumSelectionCursorID == album.id
        let isMultiSelection = isSelected && gridVM.highlightedAlbumIDs.count > 1
        AlbumGridItemView(
          album: album,
          isExpanded: isExpanded,
          isSelected: isSelected,
          isCursor: isCursor,
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
        // Phase 49/61: Combined gesture with debounced single-click and priority double-click.
        // Phase 61 fix: Plain single-click immediately sets cursor/selection but DELAYS
        // expansion (keepFirstAttemptInstead: false) so double-click can cancel it.
        // This prevents layout shifts from moving the item before the second click arrives.
        .simultaneousGesture(
          TapGesture(count: 2)
            .onEnded { _ in
              gridVM.onAlbumDoubleClicked(album)
              gridVM.albumClickDebouncer.cancelOnMain()
              gridVM.albumClickDebouncer.debounceOnMain(
                keepFirstAttemptInstead: true
              ) {
                gridVM.expandedAlbumID = album.id
                gridVM.highlightedAlbumIDs = [album.id]
                gridVM.albumSelectionFixedAnchorID = album.id
                gridVM.albumSelectionCursorID = album.id
              }
            }
            .simultaneously(
              with: TapGesture(count: 1)
                .onEnded {
                  // Phase 63: Use SwiftUI EventModifiers instead of NSEvent.
                  let hasModifier = vm.currentModifiers.contains(.shift)
                    || vm.currentModifiers.contains(.command)
                  // Phase 61: For plain clicks, immediately enter "cursor selected"
                  // state so the album visually highlights in place without moving.
                  if !hasModifier {
                    gridVM.highlightedAlbumIDs = [album.id]
                    gridVM.albumSelectionFixedAnchorID = album.id
                    gridVM.albumSelectionCursorID = album.id
                  }
                  Task {
                    gridVM.albumClickDebouncer.debounceOnMain(
                      keepFirstAttemptInstead: hasModifier
                    ) {
                      // Phase 62: No wrapper needed — gridVM accesses mainVM directly.
                      gridVM.handleAlbumSelection(album: album)
                    }
                  }
                }
            )
        )
        .contextMenu {
          albumContextMenu(for: album)
        }
        .frame(maxWidth: .infinity)
      }
      // Invisible spacers to keep alignment when the row is not full.
      // Defensive: ensure spacerCount is never negative (edge case: columnCount may change during resize).
      let spacerCount = max(0, columnCount - row.count)
      if spacerCount > 0 {
        ForEach(0 ..< spacerCount, id: \.self) { _ in
          Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
        }
      }
    }
  }

  // MARK: - Context Menu

  @ViewBuilder
  private func albumContextMenu(for album: Album) -> some View {
    let selectedAlbums = gridVM.highlightedAlbumIDs.contains(album.id)
      ? gridVM.displayedAlbums.filter { gridVM.highlightedAlbumIDs.contains($0.id) }
      : [album]
    AlbumContextMenu(
      albums: selectedAlbums,
      library: vm.library,
      audioPlayer: vm.player,
      currentPlaylistID: vm.selectedPlaylistID,
      searchText: vm.searchText,
      searchFilterMode: vm.searchFilterMode,
      onShowTrackInfo: {
        gridVM.showTrackInfo(for: selectedAlbums)
      },
      onShowDeleteConfirmation: {
        gridVM.albumsToDelete = selectedAlbums
        gridVM.showDeleteConfirmation = true
      },
      onNewPlaylistWithTracks: { trackIDs in
        gridVM.trackIDsForNewPlaylist = trackIDs
        gridVM.newPlaylistName = ""
        gridVM.showNewPlaylistAlert = true
      }
    )
  }

  // Phase 49: Only assign expandedAlbumID if the value is different.
  // Prevents redundant layout animations when the value hasn't changed.
}

// MARK: - AlbumFramePreferenceKey

private struct AlbumFramePreferenceKey: PreferenceKey {
  nonisolated static var defaultValue: [UUID: CGRect] { [:] }

  nonisolated static func reduce(
    value: inout [UUID: CGRect],
    nextValue: () -> [UUID: CGRect]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}

// MARK: - ExpandedAlbumFramePreferenceKey

// Frame of the expanded album detail pane. Used by the blank-area tap
// recogniser in the background layer so that clicking inside the pane itself
// does not close it.
struct ExpandedAlbumFramePreferenceKey: PreferenceKey {
  nonisolated static var defaultValue: CGRect? { nil }

  nonisolated static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
    // always take the latest non-nil value
    if let next = nextValue() {
      value = next
    }
  }
}
