// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TrackFramePreferenceKey

private struct TrackFramePreferenceKey: PreferenceKey {
  nonisolated static var defaultValue: [UUID: CGRect] { [:] }

  nonisolated static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
    value.merge(nextValue()) { _, new in new }
  }
}

// MARK: - AlbumVGrid.VerticallyExpandedAlbumView

/// The detail pane shown when an album is expanded in the grid.
/// Displays album art on the left, track listing on the right.
/// Phase 145: Renamed from `ExpandedAlbumView` and nested under `AlbumVGrid` namespace.
extension AlbumVGrid {
  struct VerticallyExpandedAlbumView: View {
    // MARK: Lifecycle

    init(
      album: Album,
      showBackground: Bool = true,
      currentTrackID: UUID? = nil,
      containerWidth: CGFloat,
      selectedTrackIDs: Binding<Set<UUID>>,
      onClose: @escaping () -> Void
    ) {
      self.album = album
      self.showBackground = showBackground
      self.currentTrackID = currentTrackID
      self.containerWidth = containerWidth
      self._selectedTrackIDs = selectedTrackIDs
      self.onClose = onClose
    }

    // MARK: Internal

    var body: some View {
      HStack(alignment: .top, spacing: 20) {
        // Track listing
        VStack(alignment: .leading, spacing: 0) {
          header
          trackList
          songCountAndLengthView
            .padding(.top, 8 * vm.uiFactor)
        }

        // Large album artwork
        VStack {
          LazyAlbumArtworkView(album: album)
            .frame(width: 200 * vm.uiFactor, height: 200 * vm.uiFactor)
        }
        .fixedSize()
        .onTapGesture(count: 2) {
          // Phase 38: Double-click to play album
          let sorted = album.tracks
          if let first = sorted.first {
            vm.gridVM.onTrackDoubleClicked(first, albumTracks: sorted)
          }
        }
        .contextMenu {
          // Phase 38: Right-click context menu for album artwork
          AlbumContextMenu(
            albums: [album],
            library: vm.library,
            audioPlayer: vm.player,
            currentPlaylistID: vm.selectedPlaylistID,
            searchText: vm.searchText,
            searchFilterMode: vm.searchFilterMode,
            onShowTrackInfo: {
              tracksForTrackInfo = album.tracks
              Task {
                var metadataList: [DetailedTrackMetadata?] = []
                for tr in tracksForTrackInfo {
                  let metadata = await MetadataReader.readDetailedMetadata(from: tr.fileURL)
                  metadataList.append(metadata)
                }
                detailedMetadataList = metadataList
                isTrackInfoPresented = true
              }
            },
            onShowDeleteConfirmation: {
              tracksToDelete = album.tracks
              showDeleteConfirmation = true
            },
            onNewPlaylistWithTracks: { trackIDs in
              trackIDsForNewPlaylist = trackIDs
              newPlaylistName = ""
              showNewPlaylistAlert = true
            }
          )
        }
      }
      .padding(16 * vm.uiFactor)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(showBackground ? Color.secondary.opacity(0.1) : Color.clear)
      )
      .padding(.horizontal, 4 * vm.uiFactor)
      // Phase 111: Write frame directly to ViewModel instead of
      // ExpandedAlbumFramePreferenceKey to avoid preference propagation overhead.
      .onGeometryChange(for: CGRect.self) { geo in
        geo.frame(in: .named("albumGrid"))
      } action: { frame in
        vm.gridVM.expandedAlbumFrame = frame
      }
      .sheet(isPresented: $isTrackInfoPresented) {
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
      .alert(
        String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
        isPresented: $showDeleteConfirmation
      ) {
        Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
        Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
          let trackIDs = Set(tracksToDelete.map(\.id))
          Task {
            await vm.removeTracksFromLibrary(trackIDs)
          }
          tracksToDelete = []
        }
      } message: {
        Text("i18n:Alert.RemoveTracksMessage:\(tracksToDelete.count)", bundle: #bundle)
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

    @Binding private var selectedTrackIDs: Set<UUID>

    @State private var vm: MadTunesViewModel = .shared

    // Track Info Sheet state
    @State private var isTrackInfoPresented = false
    @State private var tracksForTrackInfo: [Track] = []
    @State private var detailedMetadataList: [DetailedTrackMetadata?] = []

    // Delete Confirmation state
    @State private var showDeleteConfirmation = false
    @State private var tracksToDelete: [Track] = []

    // New Playlist alert state
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var trackIDsForNewPlaylist: Set<UUID> = []

    @State private var lastClickedTrackID: UUID?
    @State private var trackFrames: [UUID: CGRect] = [:]
    @State private var dragAnchorTrackID: UUID?
    @State private var preDragSelection: Set<UUID> = []
    @State private var isDragSelecting = false

    private let showBackground: Bool

    private let album: Album
    private var currentTrackID: UUID?
    private let containerWidth: CGFloat
    private let onClose: () -> Void

    /// Track list width computed deterministically from the parent container width.
    /// Subtracts: LazyVStack padding (2×16=32), .padding(.horizontal,4) (2×4=8),
    /// inner .padding(16) (2×16=32), artwork (200), HStack spacing (20).
    private var trackListWidth: CGFloat {
      let factor = vm.uiFactor * vm.uiFactor
      return Swift.max(300 * factor, containerWidth - 292 * factor)
    }

    // MARK: - Subviews

    private var header: some View {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(album.title)
            .font(.title2)
            .fontWeight(.bold)
          Text(album.artist)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        // Play-all badge
        Button {
          let sorted = album.tracks
          if let first = sorted.first {
            vm.gridVM.onTrackDoubleClicked(first, albumTracks: sorted)
          }
        } label: {
          Image(systemName: "play.circle.fill")
            .font(.title)
            .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)

        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
      }
      .padding(.bottom, 8 * vm.uiFactor)
    }

    @ViewBuilder private var trackList: some View {
      // Phase 58: Albums in currentAlbumsDisplayed already contain only filtered tracks.
      // Just use album.tracks directly — no additional filtering needed.
      let sorted: [Track] = album.tracks

      if !sorted.isEmpty {
        let hideArtist = album.allTrackArtistsSameAsAlbumArtist
        let showDisc = album.showDiscNumber
        let maxRowsPerColumn = 7

        let columnCount = trackListColumnCount(
          trackCount: sorted.count,
          availableWidth: trackListWidth,
          maxRowsPerColumn: maxRowsPerColumn
        )
        let useSingleColumn = columnCount == 1
        let itemsPerColumn = Int(ceil(Double(sorted.count) / Double(columnCount)))
        let columns: [[Track]] = stride(from: 0, to: sorted.count, by: itemsPerColumn).map {
          Array(sorted[$0 ..< min($0 + itemsPerColumn, sorted.count)])
        }

        HStack(alignment: .top, spacing: 6) {
          ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
            VStack(spacing: 0) {
              ForEach(Array(column.enumerated()), id: \.offset) { offset, track in
                VStack(spacing: 0) {
                  if offset == 0 {
                    songDividerInList
                  }
                  TrackRow(
                    track: track,
                    hideArtist: hideArtist,
                    showDiscNumber: showDisc,
                    isPlaying: track.id == currentTrackID,
                    isSelected: selectedTrackIDs.contains(track.id)
                  )
                  .contentShape(Rectangle())
                  // 外置 simultaneousGesture 可以徹底消滅單擊時的延遲。
                  // 這樣在執行內層雙擊任務時會連帶觸發單擊的操作。但在當前視圖這是符合需求的行為。
                  .onTapGesture(count: 2) {
                    Task { @MainActor in
                      vm.gridVM.onTrackDoubleClicked(track, albumTracks: sorted)
                    }
                  }
                  .simultaneousGesture(
                    TapGesture(count: 1)
                      .onEnded { _ in
                        handleTrackSelection(track, in: sorted)
                      }
                  )
                  .background(
                    GeometryReader { geo in
                      Color.clear.preference(
                        key: TrackFramePreferenceKey.self,
                        value: [track.id: geo.frame(in: .named("trackList"))]
                      )
                    }
                  )
                  .contextMenu {
                    let selectedTracks = selectedTrackIDs.contains(track.id)
                      ? sorted.filter { selectedTrackIDs.contains($0.id) }
                      : [track]
                    TrackContextMenu(
                      tracks: selectedTracks,
                      library: vm.library,
                      audioPlayer: vm.player,
                      currentPlaylistID: vm.selectedPlaylistID,
                      onShowTrackInfo: {
                        tracksForTrackInfo = selectedTracks
                        Task {
                          var metadataList: [DetailedTrackMetadata?] = []
                          for tr in tracksForTrackInfo {
                            let metadata = await MetadataReader.readDetailedMetadata(from: tr.fileURL)
                            metadataList.append(metadata)
                          }
                          detailedMetadataList = metadataList
                          isTrackInfoPresented = true
                        }
                      },
                      onShowDeleteConfirmation: {
                        tracksToDelete = selectedTracks
                        showDeleteConfirmation = true
                      },
                      onNewPlaylistWithTracks: { trackIDs in
                        trackIDsForNewPlaylist = trackIDs
                        newPlaylistName = ""
                        showNewPlaylistAlert = true
                      }
                    )
                  }
                  songDividerInList
                }
              }
            }
            // 僅單欄時，最大欄寬 500px。
            .frame(
              maxWidth: useSingleColumn ? 500 : .infinity,
              alignment: .leading
            )
          }
          if useSingleColumn {
            Spacer()
          }
        }
        .coordinateSpace(name: "trackList")
        .onPreferenceChange(TrackFramePreferenceKey.self) { trackFrames = $0 }
        .gesture(
          DragGesture(minimumDistance: 4, coordinateSpace: .named("trackList"))
            .onChanged { value in
              handleDragSelection(
                startLocation: value.startLocation,
                currentLocation: value.location,
                sorted: sorted
              )
            }
            .onEnded { _ in
              isDragSelecting = false
              dragAnchorTrackID = nil
            }
        )
      }
    }

    @ViewBuilder private var songCountAndLengthView: some View {
      HStack {
        Text("i18n:Unit:Track:\(album.tracks.count)", bundle: #bundle)
        Spacer()
        Text(formatDuration(album.totalDuration))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }

    @ViewBuilder private var songDividerInList: some View {
      LinearGradient(
        colors: [
          Color.clear,
          Color.primary.opacity(0.2),
          Color.primary.opacity(0.1),
          Color.primary.opacity(0.05),
          Color.clear,
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(height: 1)
    }

    private func trackListColumnCount(
      trackCount: Int, availableWidth: CGFloat, maxRowsPerColumn: Int
    )
      -> Int {
      let minColumnWidth: CGFloat = 300
      let maxPossibleColumns = max(1, Int(availableWidth / minColumnWidth))
      let desiredColumns = trackCount > maxRowsPerColumn ? maxPossibleColumns : 1
      return max(1, min(trackCount, desiredColumns))
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

    private func handleTrackSelection(_ track: Track, in sortedTracks: [Track]) {
      // Phase 63: Use SwiftUI EventModifiers instead of NSEvent.
      let modifiers = vm.currentModifiers
      if modifiers.contains(.command) {
        if selectedTrackIDs.contains(track.id) {
          selectedTrackIDs.remove(track.id)
        } else {
          selectedTrackIDs.insert(track.id)
        }
        lastClickedTrackID = track.id
      } else if modifiers.contains(.shift),
                let lastID = lastClickedTrackID,
                let lastIdx = sortedTracks.firstIndex(where: { $0.id == lastID }),
                let curIdx = sortedTracks.firstIndex(where: { $0.id == track.id }) {
        // Phase 127: Replace selection with anchor-to-current range instead of
        // inserting, so that narrowing the range (e.g. A→E then Shift+C) correctly
        // deselects items outside the new range. Anchor (lastClickedTrackID) is NOT
        // updated on Shift-clicks to keep the pivot stable.
        let range = min(lastIdx, curIdx) ... max(lastIdx, curIdx)
        var newSelection = Set<UUID>()
        for i in range {
          newSelection.insert(sortedTracks[i].id)
        }
        selectedTrackIDs = newSelection
      } else {
        selectedTrackIDs = [track.id]
        lastClickedTrackID = track.id
      }
      // Phase 127: Sync VM-level anchor/cursor so that Shift+Arrow after a click
      // starts from the clicked track rather than a stale keyboard cursor.
      vm.trackSelectionAnchorID = lastClickedTrackID
      vm.trackSelectionCursorID = track.id
    }

    private func handleDragSelection(
      startLocation: CGPoint, currentLocation: CGPoint, sorted: [Track]
    ) {
      // Phase 63: Use SwiftUI EventModifiers instead of NSEvent.
      let modifiers = vm.currentModifiers
      // 僅在摁住 Shift 或 Command 時才啟用拖拽選擇，
      // 避免與未來的拖放（drag-and-drop）功能衝突。
      guard modifiers.contains(.shift) || modifiers.contains(.command) else {
        return
      }
      if !isDragSelecting {
        isDragSelecting = true
        dragAnchorTrackID = trackIDAtLocation(startLocation)
        if modifiers.contains(.command) {
          preDragSelection = selectedTrackIDs
        } else {
          preDragSelection = []
        }
      }
      guard let anchorID = dragAnchorTrackID,
            let currentID = trackIDAtLocation(currentLocation),
            let anchorIdx = sorted.firstIndex(where: { $0.id == anchorID }),
            let currentIdx = sorted.firstIndex(where: { $0.id == currentID })
      else { return }
      let range = min(anchorIdx, currentIdx) ... max(anchorIdx, currentIdx)
      var newSelection = preDragSelection
      for i in range {
        newSelection.insert(sorted[i].id)
      }
      selectedTrackIDs = newSelection
    }

    private func trackIDAtLocation(_ point: CGPoint) -> UUID? {
      trackFrames.first { $0.value.contains(point) }?.key
    }
  }
} // extension AlbumVGrid

// MARK: - TrackRow

struct TrackRow: View {
  // MARK: Lifecycle

  init(
    track: Track,
    hideArtist: Bool = false,
    showDiscNumber: Bool = false,
    isPlaying: Bool = false,
    isSelected: Bool = false
  ) {
    self.track = track
    self.hideArtist = hideArtist
    self.showDiscNumber = showDiscNumber
    self.isPlaying = isPlaying
    self.isSelected = isSelected
  }

  // MARK: Internal

  var body: some View {
    HStack(spacing: 8) {
      if isPlaying {
        Image(systemName: "speaker.wave.2.fill")
          .frame(width: 32 * vm.uiFactor, alignment: .trailing)
          .foregroundStyle(Color.madTunesAccent)
          .font(.caption)
      } else {
        Text(trackNumberLabel)
          .frame(width: 32 * vm.uiFactor, alignment: .trailing)
          .foregroundStyle(.secondary)
          .font(.callout.monospacedDigit())
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(track.title)
          .font(.callout)
          .lineLimit(1)
        if !hideArtist {
          Text(track.artist)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      Text(formatDuration(track.duration))
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 52 * vm.uiFactor, alignment: .trailing)
    }
    .padding(.vertical, 6 * vm.uiFactor)
    .padding(.horizontal, 8 * vm.uiFactor)
    .background(
      RoundedRectangle(cornerRadius: 4).fill(trackRowBackground)
    )
    .onHover { hovered in
      Task { @MainActor in
        isHovered = hovered
      }
    }
  }

  // MARK: Private

  @State private var isHovered: Bool = false
  @State private var vm: MadTunesViewModel = .shared

  private let track: Track
  private var hideArtist: Bool = false
  private var showDiscNumber: Bool = false
  private var isPlaying: Bool = false
  private var isSelected: Bool = false

  private var trackRowBackground: Color {
    if isSelected {
      return Color.madTunesAccent.opacity(0.15)
    } else if isHovered {
      return Color.primary.opacity(0.05)
    }
    return Color.clear
  }

  private var trackNumberLabel: String {
    if track.trackNumber <= 0 { return " " }
    if showDiscNumber {
      return "\(track.discNumber)-\(track.trackNumber)"
    }
    return "\(track.trackNumber)"
  }
}
