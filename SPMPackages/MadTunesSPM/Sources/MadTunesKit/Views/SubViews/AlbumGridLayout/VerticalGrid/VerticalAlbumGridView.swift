// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumVGrid.VerticalAlbumGridView

/// iTunes 11-style album grid. Clicking an album expands a detail pane below that row.
/// Phase 145: Renamed from `AlbumGridView` and nested under `AlbumVGrid` namespace.
extension AlbumVGrid {
  struct VerticalAlbumGridView: View {
    // MARK: Lifecycle

    /// Phase 62: Simplified init — shared state (expandedAlbumID,
    /// highlightedAlbumIDs, selectedTrackIDs) is read from vm directly.
    init() {}

    // MARK: Internal

    var body: some View {
      mainContent
        .safeAreaInset(edge: .bottom, spacing: 0) {
          // Expanded detail for the expanded album (if it belongs to this row).
          if gridVM.legacyHardwareMode,
             let expandedAlbum = gridVM.displayedAlbums.first(
               where: { $0.id == gridVM.expandedAlbumID }
             ) {
            let id = "\(expandedAlbum.id)_\(Int(canvasWidth))"
            ScrollViewReader { proxy in
              ScrollView {
                VerticallyExpandedAlbumView(
                  album: expandedAlbum,
                  showBackground: false,
                  currentTrackID: currentTrackID,
                  containerWidth: canvasWidth,
                  selectedTrackIDs: Bindable(vm).selectedTrackIDs,
                  onClose: { gridVM.expandedAlbumID = nil }
                )
                .drawingGroup()
                .id(id)
                .onAppear {
                  gridVM.expandedAlbumWasInView = true
                }
                .onDisappear {
                  gridVM.expandedAlbumWasInView = false
                }
              }
              .scrollContentBackground(.hidden)
              .background {
                Rectangle()
                  .fill(.ultraThickMaterial)
                  .overlay {
                    ReusableAlbumExpansionBackground(album: expandedAlbum)
                      .id(expandedAlbum.id) // <- Required.
                  }
                  .ignoresSafeArea(.all)
                  .allowsHitTesting(false)
              }
              .onChange(of: gridVM.expandedAlbumID) { _, newVal in
                guard newVal != nil else { return }
                withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
                  gridVM.scrollToAlbumID = expandedAlbum.id
                  proxy.scrollTo(id, anchor: .top)
                }
              }
              // Phase 153: Legacy-mode track scroll trigger (keyboard navigation).
              .onChange(of: gridVM.expandedTrackScrollTargetID) { _, newID in
                guard let newID else { return }
                withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
                  // 此處不用強行指定 Anchor。
                  proxy.scrollTo(newID)
                }
                gridVM.expandedTrackScrollTargetID = nil
              }
            }
            .compositingGroup()
            .shadow(radius: 8 * vm.uiFactor)
            .padding(.horizontal)
            .frame(
              width: vm.screenVM.mainColumnCanvasSizeObserved.width,
              height: (220 + 20) * vm.uiFactor
            )
            .onAppear {
              withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
                gridVM.scrollToAlbumID = expandedAlbum.id
              }
            }
          }
        }
        .opacity(screenVM.windowSizeEverObserved ? 1 : 0)
        // Phase 54: Unify the animated response against `expandedAlbumID` changes.
        .animation(
          .interactiveSpring(duration: 0.2).nerf(gridVM.legacyHardwareMode),
          value: gridVM.expandedAlbumID
        )
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

    @Environment(\.colorScheme) private var colorScheme

    @State private var vm: MadTunesViewModel = .shared
    @State private var screenVM: ScreenVM = .shared

    /// Phase 165: Frozen column count — only updates when debounced scrollViewInnerCanvasWidth changes,
    /// preventing column count jitter from scrollbar appearance/disappearance.
    @State private var frozenColumnCount: Int = 1

    private let scrollBarWidth: CGFloat = OS.type == .macOS
      ? (15 * ThisDevice.uiFactor)
      : 0

    private let spacing: CGFloat = 16 * ThisDevice.uiFactor

    private let minItemWidth: CGFloat = 160 * ThisDevice.uiFactor

    private var albums: [Album] {
      // Phase 111: Use cached display buffer instead of recomputing
      // currentAlbumsDisplayed on every access (was ~12.8% CPU).
      gridVM.displayedAlbums
    }

    // Phase 53: Only show playing indicator when actively playing.
    private var currentTrackID: UUID? {
      vm.player.isPlaying ? vm.player.currentTrack?.id : nil
    }

    // Phase 60: Sub-ViewModel reference.
    private var gridVM: AlbumGridViewModel { vm.gridVM }

    private var scrollViewInnerCanvasWidth: CGFloat {
      screenVM.mainColumnCanvasSizeObserved.width - scrollBarWidth
    }

    private var canvasWidth: CGFloat {
      screenVM.mainColumnCanvasSizeObserved.width
    }

    /// Raw computed column count — use `frozenColumnCount` in layout instead.
    private var computedColumnCount: Int {
      max(1, Int((scrollViewInnerCanvasWidth - spacing) / (minItemWidth + spacing)))
    }

    /// Whether rubber-band drag selection is allowed (no expanded album).
    private var isDragSelectionEnabled: Bool {
      gridVM.expandedAlbumID == nil
    }

    /// The normalised selection rectangle from drag origin to current position.
    private var selectionRect: CGRect? {
      gridVM.selectionRect
    }

    /// Phase 150: Dynamic item width based on actual inner scroll content height.
    /// When macOS scrollbar is visible, inner content height shrinks; itemWidth
    /// shrinks accordingly so the artwork aspect ratio stays correct.
    private var itemWidth: CGFloat {
      let paddings = 2 * spacing
      let gaps = CGFloat(frozenColumnCount - 1) * spacing
      let innerContentWidth = scrollViewInnerCanvasWidth - paddings - gaps
      let perItemSlot = innerContentWidth / CGFloat(max(1, frozenColumnCount))
      return max(minItemWidth, perItemSlot)
    }

    // MARK: - Content Views

    @ViewBuilder private var mainContent: some View {
      ScrollViewReader { proxy in
        GeometryReader { viewport in
          let rows = gridVM.displayedAlbums.chunked(into: frozenColumnCount)
          ScrollView {
            gridScrollContent(rows: rows, viewportHeight: viewport.size.height)
              .frame(width: scrollViewInnerCanvasWidth, alignment: .topLeading)
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
          .scrollIndicators(.visible)
          .animation(.none, value: scrollViewInnerCanvasWidth)
          .scrollContentBackground(.hidden)
          .onChange(of: gridVM.expandedAlbumID) { _, newValue in
            respondToExpandedAlbumIDChanges(id: newValue, proxy: proxy)
          }
          .task {
            syncFrozenColumnCount(computedColumnCount)
            respondToExpandedAlbumIDChanges(proxy: proxy)
          }
          .onChange(of: scrollViewInnerCanvasWidth) { oldWidth, newWidth in
            syncFrozenColumnCount(computedColumnCount)
            guard oldWidth != newWidth, let expandedID = gridVM.expandedAlbumID else { return }
            let wasVisible = gridVM.expandedAlbumWasInView
            guard wasVisible else { return }
            gridVM.proxyScrollDebouncer.debounceOnMain {
              withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
                proxy.scrollTo("\(expandedID)_\(Int(newWidth))")
              }
            }
          }
          .onChange(of: gridVM.scrollToAlbumID) { _, newValue in
            guard let albumID = newValue else { return }
            gridVM.scrollToAlbumID = nil
            let allAlbums = gridVM.currentAlbumsDisplayed

            @MainActor
            func trailingTask() {
              let rows = allAlbums.chunked(into: frozenColumnCount)
              guard let rowIndex = rows.firstIndex(
                where: { $0.contains { $0.id == albumID } }
              ) else { return }
              withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
                let isAlbumGridItemVisible = gridVM.albumFrames[albumID] != nil
                if isAlbumGridItemVisible, let newValue, gridVM.expandedAlbumID == albumID, !gridVM.legacyHardwareMode {
                  proxy.scrollTo("\(newValue)_\(Int(scrollViewInnerCanvasWidth))")
                } else {
                  proxy.scrollTo(rowIndex, anchor: gridVM.legacyHardwareMode ? .bottom : .center)
                }
              }
            }

            if !gridVM.displayedAlbums.contains(where: { $0.id == albumID }) {
              gridVM.scheduleDisplayedAlbumsUpdate(to: allAlbums, ensureVisibleAlbumID: albumID) {
                trailingTask()
              }
            } else {
              trailingTask()
            }
          }
        }
      }
      .frame(width: canvasWidth, alignment: .topLeading)
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .background(alignment: .trailing) {
        if scrollBarWidth > 0 {
          // 始終顯示捲動調的佔位符，以保證視覺平衡。
          Color.primary.colorInvert().brightness(-0.4).opacity(0.3)
            .frame(width: scrollBarWidth)
            .clipShape(.capsule)
            .padding(1)
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
          DragGesture(minimumDistance: 0, coordinateSpace: .named("albumVGrid"))
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
            DragGesture(minimumDistance: 4, coordinateSpace: .named("albumVGrid"))
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
              .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
          )
          .frame(width: rect.width, height: rect.height)
          .position(x: rect.midX, y: rect.midY)
          .allowsHitTesting(false)
      }
    }

    @ViewBuilder
    private func gridScrollContent(rows: [[Album]], viewportHeight: CGFloat) -> some View {
      LazyVStack(alignment: .leading, spacing: spacing) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          albumRow(row, columnCount: frozenColumnCount)
            .padding(.horizontal, 6 * vm.uiFactor) // 防止邊緣陰影被切掉。
            .frame(width: scrollViewInnerCanvasWidth, alignment: .topLeading)
            .drawingGroup()

          // Expanded detail for the expanded album (if it belongs to this row).
          if !gridVM.legacyHardwareMode,
             let expandedAlbum = row.first(where: { $0.id == gridVM.expandedAlbumID }) {
            VerticallyExpandedAlbumView(
              album: expandedAlbum,
              showBackground: true,
              currentTrackID: currentTrackID,
              containerWidth: scrollViewInnerCanvasWidth,
              selectedTrackIDs: Bindable(vm).selectedTrackIDs,
              onClose: { gridVM.expandedAlbumID = nil }
            )
            .padding(.horizontal, 6 * vm.uiFactor) // 防止邊緣陰影被切掉。
            .drawingGroup()
            .id("\(expandedAlbum.id)_\(Int(scrollViewInnerCanvasWidth))")
            .onAppear { gridVM.expandedAlbumWasInView = true }
            .onDisappear { gridVM.expandedAlbumWasInView = false }
            .shadow(
              color: Color(.sRGBLinear, white: 0, opacity: 0.33),
              radius: 3 * ThisDevice.uiFactor
            )
          }
        }
      }
      // Phase 131: Ensure content fills viewport so bottom blank area
      // remains inside albumGrid coordinate space for rubber-band selection.
      .padding(max(0, spacing - 6 * vm.uiFactor))
      .frame(minHeight: max(viewportHeight, 0), alignment: .topLeading)
      .coordinateSpace(name: "albumVGrid")
      .onPreferenceChange(AlbumFramePreferenceKey.self) { frames in
        gridVM.albumFrames = frames
      }
      .background {
        rubberBandDragLayer
      }
      .overlay {
        rubberBandRectOverlay
      }
      // 對整個 VerticalAlbumGridView 的 drawingGroup 對 Intel Mac 負擔太大，所以拆除。
      // 但對每個 Row 仍舊有必要施加，否則在 Apple Silicon Mac 上的 FPS 會從 full (60fps) 掉到 30fps 以下，非常噁心。
      // 相關的實作已經套用到上文了，施加對象是 albumRow 與 VerticallyExpandedAlbumView 副本。
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
            isMultipleSelection: isMultiSelection,
            legacyHardwareMode: gridVM.legacyHardwareMode
          )
          .frame(width: Swift.max(0, itemWidth))
          .background(
            GeometryReader { geo in
              Color.clear.preference(
                key: AlbumFramePreferenceKey.self,
                value: [album.id: geo.frame(in: .named("albumVGrid"))]
              )
            }
          )
          .contentShape(Rectangle())
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
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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

    private func syncFrozenColumnCount(_ newCount: Int) {
      let clampedCount = max(1, newCount)
      if frozenColumnCount != clampedCount {
        frozenColumnCount = clampedCount
      }
      if gridVM.vGridFrozenColumnCount != clampedCount {
        gridVM.vGridFrozenColumnCount = clampedCount
      }
    }

    // Phase 49: Only assign expandedAlbumID if the value is different.
    // Prevents redundant layout animations when the value hasn't changed.

    private func respondToExpandedAlbumIDChanges(id newValue: UUID? = nil, proxy: ScrollViewProxy) {
      // Phase 96: expandedAlbumID scroll (data scheduling moved to ViewModel).
      // Phase 98: In Intel Mac mode, skip auto-scroll to VerticallyExpandedAlbumView;
      // scrolling to AlbumGridItemView is handled in the safeAreaInset onChange.
      guard let newValue = newValue ?? vm.gridVM.expandedAlbumID else { return }
      gridVM.scheduleDisplayedAlbumsUpdate(
        to: gridVM.currentAlbumsDisplayed,
        ensureVisibleAlbumID: newValue
      ) {
        guard !gridVM.legacyHardwareMode else { return }
        withAnimation(.interactiveSpring.nerf(gridVM.legacyHardwareMode)) {
          proxy.scrollTo("\(newValue)_\(Int(scrollViewInnerCanvasWidth))")
        }
      }
    }
  }
} // extension AlbumVGrid

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
