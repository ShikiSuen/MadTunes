// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumGridView

/// iTunes 11-style album grid. Clicking an album expands a detail pane below that row.
struct AlbumGridView: View {
  // MARK: Lifecycle

  init(
    albums: [Album],
    expandedAlbumID: Binding<UUID?>,
    highlightedAlbumIDs: Binding<Set<UUID>>,
    selectedTrackIDs: Binding<Set<UUID>>,
    currentTrackID: UUID? = nil,
    onTrackSelected: @escaping (Track, [Track]) -> Void,
    onAlbumDoubleClicked: ((Album) -> Void)? = nil
  ) {
    self.albums = albums
    self._expandedAlbumID = expandedAlbumID
    self._highlightedAlbumIDs = highlightedAlbumIDs
    self._selectedTrackIDs = selectedTrackIDs
    self.currentTrackID = currentTrackID
    self.onTrackSelected = onTrackSelected
    self.onAlbumDoubleClicked = onAlbumDoubleClicked
  }

  // MARK: Internal

  var body: some View {
    mainContent
      .animation(canvasAnimation, value: canvasWidth)
      .opacity(screenVM.windowSizeEverObserved ? 1 : 0)
      .sheet(isPresented: $isTrackInfoPresented) {
        trackInfoSheetContent
      }
      .alert(
        String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
        isPresented: $showDeleteConfirmation
      ) {
        Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
        Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
          let trackIDs = Set(albumsToDelete.flatMap { $0.tracks.map(\.id) })
          vm.library.removeTracks(ids: trackIDs)
          albumsToDelete = []
        }
      } message: {
        Text(String(
          localized: "i18n:Alert.RemoveAlbumsMessage",
          defaultValue: "This will remove \(albumsToDelete.count) album(s) from the library. The original files will not be deleted.",
          bundle: #bundle
        ))
      }
      .alert(
        String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
        isPresented: $showNewPlaylistAlert
      ) {
        TextField(
          String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
          text: $newPlaylistName
        )
        Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
          commitNewPlaylistAlert()
        }
        Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      }
  }

  // MARK: Private

  @Binding private var expandedAlbumID: UUID?
  @Binding private var highlightedAlbumIDs: Set<UUID>
  @Binding private var selectedTrackIDs: Set<UUID>
  @State private var vm: MadTunesViewModel = .shared
  @State private var screenVM: ScreenVM = .shared
  @State private var expandedAlbumWasInView = false

  // Rubber-band drag selection state (macOS only).
  @State private var dragOrigin: CGPoint?
  @State private var dragCurrent: CGPoint?
  @State private var albumFrames: [UUID: CGRect] = [:]
  @State private var preDragHighlighted: Set<UUID> = []

  // Track Info Sheet state
  @State private var isTrackInfoPresented = false
  @State private var tracksForTrackInfo: [Track] = []
  @State private var detailedMetadataList: [DetailedTrackMetadata?] = []

  // Delete Confirmation state
  @State private var showDeleteConfirmation = false
  @State private var albumsToDelete: [Album] = []

  // New Playlist alert state
  @State private var showNewPlaylistAlert = false
  @State private var newPlaylistName = ""
  @State private var trackIDsForNewPlaylist: Set<UUID> = []

  @State private var expansionDebouncer: Debouncer = .init(delay: 0.3)

  private let albums: [Album]
  private var currentTrackID: UUID?
  private let onTrackSelected: (Track, [Track]) -> Void
  private var onAlbumDoubleClicked: ((Album) -> Void)?

  private let minItemWidth: CGFloat = 160
  private let spacing: CGFloat = 16

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

  private var canvasAnimation: Animation {
    let duration: TimeInterval = screenVM.windowSizeEverObserved ? 0.12 : 0
    return .easeOut(duration: duration)
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

  // MARK: - Content Views

  @ViewBuilder private var mainContent: some View {
    ScrollViewReader { proxy in
      let rows = albums.chunked(into: columnCount)
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
      .scrollContentBackground(.hidden)
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
      .onChange(of: vm.scrollToAlbumID) { _, newValue in
        guard let albumID = newValue else { return }
        vm.scrollToAlbumID = nil
        // Compute the row offset that contains the target album.
        // ForEach uses `id: \.offset` so `proxy.scrollTo(offset)` works
        // even for rows that LazyVStack hasn't realised yet.
        let rows = albums.chunked(into: columnCount)
        guard let rowIndex = rows.firstIndex(where: { $0.contains { $0.id == albumID } })
        else { return }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(50))
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(rowIndex, anchor: .center)
          }
        }
      }
    }
  }

  @ViewBuilder private var trackInfoSheetContent: some View {
    if tracksForTrackInfo.count == 1, let track = tracksForTrackInfo.first {
      TrackInfoView(
        track: track,
        detailedMetadata: detailedMetadataList.first ?? nil
      )
    } else {
      MultiTrackInfoView(
        tracks: tracksForTrackInfo,
        detailedMetadataList: detailedMetadataList
      )
    }
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
                #if canImport(AppKit) && !canImport(UIKit)
                if NSEvent.modifierFlags.contains(.command) {
                  preDragHighlighted = highlightedAlbumIDs
                } else {
                  preDragHighlighted = []
                }
                #else
                preDragHighlighted = []
                #endif
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
        // 外置 simultaneousGesture 可以徹底消滅單擊時的延遲。
        // 但這樣在執行內層雙擊任務時會連帶觸發單擊的操作，所以需要「首發准許型 Debounce」處理。
        .onTapGesture(count: 1) {
          Task { @MainActor in
            expansionDebouncer.debounceOnMain(keepFirstAttemptInstead: true) {
              withAnimation(.easeInOut(duration: 0.3)) {
                handleTrackRowSelection(album: album)
              }
            }
          }
        }
        .simultaneousGesture(
          TapGesture(count: 2)
            .onEnded { _ in
              Task { @MainActor in
                // Double-clicking an already-expanded album should NOT collapse it.
                if expandedAlbumID != album.id {
                  expansionDebouncer.debounceOnMain(keepFirstAttemptInstead: true) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                      handleTrackRowSelection(album: album)
                    }
                  }
                } else {
                  highlightedAlbumIDs = [album.id]
                }
              }
              Task { @MainActor in
                onAlbumDoubleClicked?(album)
              }
            }
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
    let selectedAlbums = highlightedAlbumIDs.contains(album.id)
      ? albums.filter { highlightedAlbumIDs.contains($0.id) }
      : [album]
    AlbumContextMenu(
      albums: selectedAlbums,
      library: vm.library,
      audioPlayer: vm.player,
      currentPlaylistID: vm.selectedPlaylistID,
      searchText: vm.searchText,
      searchFilterMode: vm.searchFilterMode,
      onShowTrackInfo: {
        showTrackInfo(for: selectedAlbums)
      },
      onShowDeleteConfirmation: {
        albumsToDelete = selectedAlbums
        showDeleteConfirmation = true
      },
      onNewPlaylistWithTracks: { trackIDs in
        trackIDsForNewPlaylist = trackIDs
        newPlaylistName = ""
        showNewPlaylistAlert = true
      }
    )
  }

  private func updateDragSelection() {
    guard let rect = selectionRect else { return }
    var selected = preDragHighlighted
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

  private func showTrackInfo(for selectedAlbums: [Album]) {
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

  private func commitNewPlaylistAlert() {
    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    let existingNames = Set(vm.library.playlists.dropFirst(2).map(\.name))
    guard !existingNames.contains(name) else { return }
    vm.library.addPlaylist(name: name)
    if let newPlaylist = vm.library.playlists.last {
      vm.library.addTracks(trackIDsForNewPlaylist, toPlaylist: newPlaylist.id)
    }
    trackIDsForNewPlaylist = []
  }
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
