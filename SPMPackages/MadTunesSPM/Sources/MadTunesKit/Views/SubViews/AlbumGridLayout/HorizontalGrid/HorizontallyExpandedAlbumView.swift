// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumHGrid.HorizontallyExpandedAlbumView

/// Phase 146: The detail pane shown when an album is expanded in the horizontal grid.
/// Unlike `VerticallyExpandedAlbumView`, this view has NO album artwork,
/// uses a single column track list, and is wrapped in a vertical ScrollView.
/// Keyboard navigation only handles up/down movement.
extension AlbumHGrid {
  struct HorizontallyExpandedAlbumView: View {
    // MARK: Lifecycle

    init(
      album: Album,
      currentTrackID: UUID? = nil,
      selectedTrackIDs: Binding<Set<UUID>>,
      onClose: @escaping () -> Void
    ) {
      self.album = album
      self.currentTrackID = currentTrackID
      self._selectedTrackIDs = selectedTrackIDs
      self.onClose = onClose
    }

    // MARK: Internal

    var body: some View {
      VStack(alignment: .leading, spacing: 12 * vm.uiFactor) {
        albumTitleInfoBar
          .padding(8 * vm.uiFactor)
          .background(Color.primary.colorInvert().brightness(0.1).opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: 4 * vm.uiFactor))
        ScrollViewReader { proxy in
          ScrollView(.vertical) {
            VStack(spacing: 0) {
              let trackCount = album.tracks.count
              ForEach(Array(album.tracks.enumerated()), id: \.element.id) { offset, track in
                VStack(spacing: 0) {
                  // 該 Divider 不再需要了，因為第一個 Track 就在頂端。
                  // if offset == 0 { songDividerInList }
                  TrackRow(
                    track: track,
                    hideArtist: album.allTrackArtistsSameAsAlbumArtist && trackCount > 15,
                    showDiscNumber: album.showDiscNumber,
                    isPlaying: track.id == currentTrackID,
                    isSelected: selectedTrackIDs.contains(track.id)
                  )
                  .contentShape(Rectangle())
                  .onTapGesture(count: 2) {
                    Task { @MainActor in
                      vm.gridVM.onTrackDoubleClicked(track, albumTracks: album.tracks)
                    }
                  }
                  .simultaneousGesture(
                    TapGesture(count: 1)
                      .onEnded { _ in
                        handleTrackSelection(track, in: album.tracks)
                      }
                  )
                  .contextMenu {
                    let selectedTracks = selectedTrackIDs.contains(track.id)
                      ? album.tracks.filter { selectedTrackIDs.contains($0.id) }
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
                  if offset != trackCount - 1 {
                    songDividerInList
                  }
                }
                .id(track.id) // Phase 153: Enable ScrollViewReader targeting.
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .scrollContentBackground(.hidden)
          // Phase 153: Auto-scroll to highlighted track during keyboard navigation.
          .onChange(of: vm.gridVM.expandedTrackScrollTargetID) { _, newID in
            if let id = newID {
              withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
                // Anchor 無須刻意指定。
                proxy.scrollTo(id)
              }
              vm.gridVM.expandedTrackScrollTargetID = nil
            }
          }
        }
      }
      .padding(12 * vm.uiFactor)
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(width: 400 * vm.uiFactor)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.secondary.opacity(0.1))
      }
      .padding(.vertical, 4 * vm.uiFactor)
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

    private let album: Album
    private var currentTrackID: UUID?
    private let onClose: () -> Void

    // MARK: - Subviews

    private var albumTitleInfoBar: some View {
      VStack {
        HStack {
          LazyAlbumArtworkView(album: album)
            .frame(width: 72 * vm.uiFactor)
            .onTapGesture(count: 2) {
              // Phase 38: Double-click to play album
              let sorted = album.tracks
              if let first = sorted.first {
                vm.gridVM.onTrackDoubleClicked(first, albumTracks: sorted)
              }
            }
          VStack(alignment: .leading, spacing: 2 * vm.uiFactor) {
            VStack(alignment: .leading, spacing: 2 * vm.uiFactor) {
              Text(album.title)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
              Text(album.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
              songCountAndLengthView
                .frame(maxWidth: .infinity)
              // Play-all badge
              Button {
                let sorted = album.tracks
                if let first = sorted.first {
                  vm.gridVM.onTrackDoubleClicked(first, albumTracks: sorted)
                }
              } label: {
                Image(systemName: "play.circle.fill")
                  .font(.title2)
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
            .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 72 * vm.uiFactor)
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
      vm.trackSelectionAnchorID = lastClickedTrackID
      vm.trackSelectionCursorID = track.id
    }
  }
} // extension AlbumHGrid
