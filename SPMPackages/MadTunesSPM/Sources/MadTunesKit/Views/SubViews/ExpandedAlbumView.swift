// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - TrackFramePreferenceKey

private struct TrackFramePreferenceKey: PreferenceKey {
  nonisolated static var defaultValue: [UUID: CGRect] { [:] }

  nonisolated static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
    value.merge(nextValue()) { _, new in new }
  }
}

// MARK: - ExpandedAlbumView

/// The detail pane shown when an album is expanded in the grid.
/// Displays album art on the left, track listing on the right.
struct ExpandedAlbumView: View {
  // MARK: Internal

  let album: Album
  var currentTrackID: UUID?
  let containerWidth: CGFloat
  @Binding var selectedTrackIDs: Set<UUID>
  let onTrackSelected: (Track, [Track]) -> Void
  let onClose: () -> Void

  // MARK: Private

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

  var body: some View {
    HStack(alignment: .top, spacing: 20) {
      // Track listing
      VStack(alignment: .leading, spacing: 0) {
        header
        trackList
        songCountAndLengthView
          .padding(.top, 8)
      }

      // Large album artwork
      VStack {
        LazyAlbumArtworkView(album: album)
          .frame(width: 200, height: 200)
      }
      .fixedSize()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(.secondary.opacity(0.1))
    )
    .padding(.horizontal, 4)
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
        vm.library.removeTracks(ids: trackIDs)
        tracksToDelete = []
      }
    } message: {
      Text(String(
        localized: "i18n:Alert.RemoveTracksMessage",
        defaultValue: "This will remove \(tracksToDelete.count) track(s) from the library. The original files will not be deleted.",
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

  @State private var lastClickedTrackID: UUID?
  @State private var trackFrames: [UUID: CGRect] = [:]
  @State private var dragAnchorTrackID: UUID?
  @State private var preDragSelection: Set<UUID> = []
  @State private var isDragSelecting = false

  /// Track list width computed deterministically from the parent container width.
  /// Subtracts: LazyVStack padding (2×16=32), .padding(.horizontal,4) (2×4=8),
  /// inner .padding(16) (2×16=32), artwork (200), HStack spacing (20).
  private var trackListWidth: CGFloat {
    max(300, containerWidth - 292)
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
        let sorted = album.sortedTracks
        if let first = sorted.first {
          onTrackSelected(first, sorted)
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
    .padding(.bottom, 8)
  }

  @ViewBuilder private var trackList: some View {
    let query = vm.searchText.trimmingCharacters(in: .whitespaces)
    let sorted: [Track] = if query.isEmpty {
      album.sortedTracks
    } else {
      album.sortedTracks.filter { track in
        track.title.localizedCaseInsensitiveContains(query)
          || track.artist.localizedCaseInsensitiveContains(query)
          || track.genre.localizedCaseInsensitiveContains(query)
          || track.albumArtist.localizedCaseInsensitiveContains(query)
          || (track.year.map(String.init) ?? "").contains(query)
      }
    }
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
              .onTapGesture(count: 2) {
                Task { @MainActor in
                  handleTrackSelection(track, in: sorted)
                }
                Task { @MainActor in
                  onTrackSelected(track, sorted)
                }
              }
              .onTapGesture(count: 1) {
                Task { @MainActor in
                  handleTrackSelection(track, in: sorted)
                }
              }
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

  @ViewBuilder private var songCountAndLengthView: some View {
    HStack {
      Text(String(
        localized: "i18n:ExpandedAlbum.SongCount",
        defaultValue: "\(album.tracks.count) songs",
        bundle: #bundle
      ))
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
    #if canImport(AppKit) && !canImport(UIKit)
    let modifiers = NSEvent.modifierFlags
    if modifiers.contains(.command) {
      if selectedTrackIDs.contains(track.id) {
        selectedTrackIDs.remove(track.id)
      } else {
        selectedTrackIDs.insert(track.id)
      }
    } else if modifiers.contains(.shift),
              let lastID = lastClickedTrackID,
              let lastIdx = sortedTracks.firstIndex(where: { $0.id == lastID }),
              let curIdx = sortedTracks.firstIndex(where: { $0.id == track.id }) {
      let range = min(lastIdx, curIdx) ... max(lastIdx, curIdx)
      for i in range {
        selectedTrackIDs.insert(sortedTracks[i].id)
      }
    } else {
      selectedTrackIDs = [track.id]
    }
    #else
    selectedTrackIDs = [track.id]
    #endif
    lastClickedTrackID = track.id
  }

  private func handleDragSelection(
    startLocation: CGPoint, currentLocation: CGPoint, sorted: [Track]
  ) {
    #if canImport(AppKit) && !canImport(UIKit)
    let modifiers = NSEvent.modifierFlags
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
    #endif
  }

  private func trackIDAtLocation(_ point: CGPoint) -> UUID? {
    trackFrames.first { $0.value.contains(point) }?.key
  }
}

// MARK: - TrackRow

struct TrackRow: View {
  // MARK: Internal

  let track: Track
  var hideArtist: Bool = false
  var showDiscNumber: Bool = false
  var isPlaying: Bool = false
  var isSelected: Bool = false

  var body: some View {
    HStack(spacing: 8) {
      if isPlaying {
        Image(systemName: "speaker.wave.2.fill")
          .frame(width: 32, alignment: .trailing)
          .foregroundStyle(Color.madTunesAccent)
          .font(.caption)
      } else {
        Text(trackNumberLabel)
          .frame(width: 32, alignment: .trailing)
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
        .frame(width: 52, alignment: .trailing)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
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
