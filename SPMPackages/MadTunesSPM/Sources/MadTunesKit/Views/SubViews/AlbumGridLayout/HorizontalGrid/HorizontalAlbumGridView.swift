// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumHGrid.HorizontalAlbumGridView

/// Phase 146: Horizontal-scroll album grid. Conceptually the same as
/// `VerticalAlbumGridView` but scrolled horizontally and "rotated 45°":
/// albums fill top-to-bottom in each column, then proceed to the next column.
/// When an album is expanded, the detail pane appears to the right of the column.
extension AlbumHGrid {
  struct HorizontalAlbumGridView: View {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    var body: some View {
      mainContent
        .opacity(screenVM.windowSizeEverObserved ? 1 : 0)
        .animation(
          .interactiveSpring(duration: 0.2).nerf(gridVM.legacyHardwareMode),
          value: gridVM.expandedAlbumID
        )
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: { newHeight in
          if measuredHeight != newHeight {
            measuredHeight = newHeight
          }
        }
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
            Task {
              await vm.removeTracksFromLibrary(trackIDs)
            }
            gridVM.albumsToDelete = []
          }
        } message: {
          Text("i18n:Alert.RemoveAlbumsMessage:\(gridVM.albumsToDelete.count)", bundle: #bundle)
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

    /// Phase 147: Measured available height (after SafeAreaInsets).
    @State private var measuredHeight: CGFloat = 0

    /// Phase 150: Measured height of the scroll content area (accounts for scrollbar).
    @State private var scrollContentHeight: CGFloat = 0

    private var spacing: CGFloat { 16 * vm.uiFactor }

    private var minItemHeight: CGFloat { 160 * vm.uiFactor }

    /// Phase 150: Dynamic item width based on actual inner scroll content height.
    /// When macOS scrollbar is visible, inner content height shrinks; itemWidth
    /// shrinks accordingly so the artwork aspect ratio stays correct.
    private var itemWidth: CGFloat {
      guard scrollContentHeight > 0 else { return minItemHeight }
      let paddings = 2 * spacing
      let gaps = CGFloat(rowCount - 1) * spacing
      let perItemSlot = (scrollContentHeight - paddings - gaps) / CGFloat(max(1, rowCount))
      // Reserve space for text labels (title .subheadline + artist .caption + spacing + padding).
      let textReserve: CGFloat = 36
      let dynamicWidth = perItemSlot - textReserve
      return max(80, min(minItemHeight, dynamicWidth))
    }

    /// Phase 150: Pre-allocated fixed height per item slot, derived from scroll content height.
    private var itemHeight: CGFloat {
      guard scrollContentHeight > 0 else { return minItemHeight + 36 }
      let paddings = 2 * spacing
      let gaps = CGFloat(rowCount - 1) * spacing
      return (scrollContentHeight - paddings - gaps) / CGFloat(max(1, rowCount))
    }

    private var albums: [Album] {
      gridVM.displayedAlbums
    }

    private var currentTrackID: UUID? {
      vm.player.isPlaying ? vm.player.currentTrack?.id : nil
    }

    private var gridVM: AlbumGridViewModel { vm.gridVM }

    private var canvasWidth: CGFloat {
      screenVM.mainColumnCanvasSizeObserved.width
    }

    private var canvasHeight: CGFloat {
      screenVM.mainColumnCanvasSizeObserved.height
    }

    /// Number of rows that fit in the visible height.
    private var rowCount: Int {
      // Phase 147: Use measuredHeight (actual available height after SafeAreaInsets)
      // instead of canvasHeight (full window height).
      let effectiveHeight = measuredHeight > 0 ? measuredHeight : canvasHeight
      return max(1, Int((effectiveHeight - spacing) / (minItemHeight + spacing)))
    }

    /// Whether rubber-band drag selection is allowed (no expanded album).
    private var isDragSelectionEnabled: Bool {
      gridVM.expandedAlbumID == nil
    }

    private var selectionRect: CGRect? {
      gridVM.selectionRect
    }

    // MARK: - Content Views

    @ViewBuilder private var mainContent: some View {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          let columns = gridVM.displayedAlbums.chunked(into: rowCount)
          LazyHStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { colIdx, column in
              albumColumn(column, rowCount: rowCount)
                .drawingGroup()
                .id(colIdx)

              // Phase 146: Expanded detail for the expanded album (if it belongs to this column).
              if let expandedAlbum = column.first(where: { $0.id == gridVM.expandedAlbumID }) {
                HorizontallyExpandedAlbumView(
                  album: expandedAlbum,
                  currentTrackID: currentTrackID,
                  selectedTrackIDs: Bindable(vm).selectedTrackIDs,
                  onClose: { gridVM.expandedAlbumID = nil }
                )
                // Phase 147: Explicit height so the inner vertical ScrollView can function
                // inside the outer horizontal LazyHStack.
                .frame(maxHeight: .infinity)
                .id("expanded_\(expandedAlbum.id)")
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .leading)))
                .onAppear { gridVM.expandedAlbumWasInView = true }
                .onDisappear { gridVM.expandedAlbumWasInView = false }
              }
            }
          }
          .padding(spacing)
          .frame(
            minWidth: max(canvasWidth, 0),
            maxHeight: .infinity,
            alignment: .topLeading
          )
          .coordinateSpace(name: "albumHGrid")
          // Phase 151: Redirect unmodified vertical scroll wheel to horizontal scrolling.
          .redirectsVerticalScrollWheelToHorizontal()
          // Phase 150: Measure the actual inner content height (accounts for scrollbar).
          .onGeometryChange(for: CGFloat.self) {
            $0.size.height
          } action: { newHeight in
            if scrollContentHeight != newHeight {
              scrollContentHeight = newHeight
              // Sync to ViewModel for keyboard navigation consistency.
              gridVM.hGridMeasuredHeight = newHeight
            }
          }
          .onPreferenceChange(AlbumFramePreferenceKey.self) { frames in
            gridVM.albumFrames = frames
          }
          .background {
            rubberBandDragLayer
          }
          .overlay {
            rubberBandRectOverlay
          }
        }
        .scrollContentBackground(.hidden)
        .onChange(of: gridVM.expandedAlbumID) { _, newValue in
          guard let newValue else { return }
          gridVM.scheduleDisplayedAlbumsUpdate(to: albums, ensureVisibleAlbumID: newValue)
          gridVM.proxyScrollDebouncer.debounceOnMain {
            withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
              // 使用者電腦顯示器往往都是寬的，所以這裡需要 anchor: .center 便於接下來的操作。
              proxy.scrollTo("expanded_\(newValue)", anchor: .center)
            }
          }
        }
        .onChange(of: gridVM.scrollToAlbumID) { _, newValue in
          guard let albumID = newValue else { return }
          gridVM.scrollToAlbumID = nil
          if !gridVM.displayedAlbums.contains(where: { $0.id == albumID }) {
            gridVM.scheduleDisplayedAlbumsUpdate(to: albums, ensureVisibleAlbumID: albumID)
          }
          let columns = albums.chunked(into: rowCount)
          guard let colIndex = columns.firstIndex(
            where: { $0.contains { $0.id == albumID } }
          ) else { return }
          gridVM.proxyScrollDebouncer.debounceOnMain {
            withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
              proxy.scrollTo(colIndex, anchor: .center)
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

    // MARK: - Rubber-Band Drag Layer

    @ViewBuilder private var rubberBandDragLayer: some View {
      // Close expanded album on tap in empty area.
      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .named("albumHGrid"))
            .onEnded { value in
              let dx = abs(value.translation.width)
              let dy = abs(value.translation.height)
              guard dx < 5, dy < 5 else { return }
              guard gridVM.expandedAlbumID != nil else { return }
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
            DragGesture(minimumDistance: 4, coordinateSpace: .named("albumHGrid"))
              .onChanged { value in
                if gridVM.dragOrigin == nil {
                  gridVM.dragOrigin = value.startLocation
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

    // MARK: - Rubber-Band Rect Overlay

    @ViewBuilder private var rubberBandRectOverlay: some View {
      if let rect = selectionRect {
        Rectangle()
          .fill(Color.accentColor.opacity(0.15))
          .overlay(
            Rectangle()
              .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
          )
          .frame(width: rect.width, height: rect.height)
          .position(x: rect.midX, y: rect.midY)
          .allowsHitTesting(false)
      }
    }

    // MARK: - Column

    @ViewBuilder
    private func albumColumn(_ column: [Album], rowCount: Int) -> some View {
      VStack(alignment: .leading, spacing: spacing) {
        ForEach(column) { album in
          let isExpanded = album.id == gridVM.expandedAlbumID
          let isSelected = gridVM.highlightedAlbumIDs.contains(album.id)
          let isCursor = gridVM.albumSelectionCursorID == album.id
          let isMultiSelection = isSelected && gridVM.highlightedAlbumIDs.count > 1
          AlbumGridItemView(
            album: album,
            isExpanded: isExpanded,
            isSelected: isSelected,
            isCursor: isCursor,
            isMultipleSelection: isMultiSelection,
            legacyHardwareMode: false
          )
          // Phase 147: Fixed width prevents long album titles from stretching the column.
          // Phase 150: Fixed height from scroll content measurement prevents VStack
          // from compressing items when macOS scrollbar consumes vertical space.
          .frame(width: itemWidth, height: itemHeight)
          .background(
            GeometryReader { geo in
              Color.clear.preference(
                key: AlbumFramePreferenceKey.self,
                value: [album.id: geo.frame(in: .named("albumHGrid"))]
              )
            }
          )
          .contentShape(Rectangle())
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
                    let hasModifier = vm.currentModifiers.contains(.shift)
                      || vm.currentModifiers.contains(.command)
                    if !hasModifier {
                      gridVM.highlightedAlbumIDs = [album.id]
                      gridVM.albumSelectionFixedAnchorID = album.id
                      gridVM.albumSelectionCursorID = album.id
                    }
                    Task {
                      gridVM.albumClickDebouncer.debounceOnMain(
                        keepFirstAttemptInstead: hasModifier
                      ) {
                        gridVM.handleAlbumSelection(album: album)
                      }
                    }
                  }
              )
          )
          .contextMenu {
            albumContextMenu(for: album)
          }
        }
        // Phase 148: Single spacer absorbs remaining vertical space
        // so partial columns stay top-aligned.
        Spacer(minLength: 0)
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
  }
} // extension AlbumHGrid

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
