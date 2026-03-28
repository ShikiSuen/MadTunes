// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPLibrarySection

/// Phase 75: Library section of the Panorama Hub with Pivot tabs
/// (Albums / Artists / Tracks / Recently Added).
struct WPLibrarySection: View {
  // MARK: Internal

  var body: some View {
    @Bindable var pvm = phoneVM
    VStack(spacing: 0) {
      // Phase 78: Pivot bar + Phase 84: Hamburger menu (replaces Column Filter button).
      HStack(spacing: 0) {
        WPPivotBar(
          currentPivot: $pvm.currentPivot,
          accentColor: phoneVM.wpAccentColor.color
        )

        // Phase 84: Hamburger menu combining Column Filter, Import, and Selection Mode.
        Menu {
          // Column Browser filter.
          Button {
            phoneVM.isColumnBrowserPresented = true
          } label: {
            Label(
              String(localized: "i18n:ColumnBrowser.Title", bundle: #bundle),
              systemImage: vm.isColumnBrowserFiltering
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle"
            )
          }

          Divider()

          // Import Files.
          Button {
            vm.isFileImporterPresented = true
          } label: {
            Label(
              String(localized: "i18n:Import.ImportFiles", bundle: #bundle),
              systemImage: "music.note"
            )
          }

          // Import Folder.
          Button {
            vm.isFolderImporterPresented = true
          } label: {
            Label(
              String(localized: "i18n:Import.ImportFolder", bundle: #bundle),
              systemImage: "folder"
            )
          }

          Divider()

          // Selection Mode toggle.
          Button {
            if phoneVM.isWPSelectionModeActive {
              phoneVM.wpSelectedAlbumIDs = []
            } else if let firstID = vm.gridVM.currentAlbumsDisplayed.first?.id {
              phoneVM.wpSelectedAlbumIDs = [firstID]
            }
          } label: {
            Label(
              phoneVM.isWPSelectionModeActive
                ? String(localized: "i18n:WP.Menu.ExitSelect", bundle: #bundle)
                : String(localized: "i18n:WP.Menu.SelectAlbums", bundle: #bundle),
              systemImage: phoneVM.isWPSelectionModeActive
                ? "xmark.circle" : "checkmark.circle"
            )
          }
        } label: {
          Image(
            systemName: vm.isColumnBrowserFiltering
              ? "line.3.horizontal.circle.fill"
              : "line.3.horizontal.circle"
          )
          .font(.system(size: 20))
          .foregroundStyle(
            vm.isColumnBrowserFiltering
              ? phoneVM.wpAccentColor.color
              : .white.opacity(0.5)
          )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
      }

      // Phase 84: Selection mode inline bar.
      if phoneVM.isWPSelectionModeActive {
        WPLibrarySelectionBar()
      }

      // Pivot content.
      TabView(selection: $pvm.currentPivot) {
        WPAlbumTilesView()
          .tag(WPPhoneViewModel.LibraryPivot.albums)

        WPArtistListView()
          .tag(WPPhoneViewModel.LibraryPivot.artists)

        WPTrackListView(tracks: vm.filteredTracksBase)
          .tag(WPPhoneViewModel.LibraryPivot.tracks)

        WPTrackListView(tracks: phoneVM.recentlyAddedTracks)
          .tag(WPPhoneViewModel.LibraryPivot.recentlyAdded)
      }
      #if os(iOS)
      .tabViewStyle(.page(indexDisplayMode: .never))
      #endif
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
}

// MARK: - WPLibrarySelectionBar

/// Phase 84: Inline selection bar displayed within Library when selection mode is active.
/// Replaces WPAppBar's selection-mode actions.
struct WPLibrarySelectionBar: View {
  // MARK: Internal

  var body: some View {
    let selectionCount = phoneVM.wpSelectedAlbumIDs.count
    let allVisibleSelected = selectionCount > 0
      && selectionCount == vm.gridVM.currentAlbumsDisplayed.count

    HStack(spacing: 16) {
      // Selection count.
      Text(verbatim: "\(selectionCount)")
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)

      Spacer(minLength: 0)

      // Select All / Deselect All.
      Button {
        if allVisibleSelected {
          phoneVM.wpSelectedAlbumIDs = []
        } else {
          phoneVM.wpSelectedAlbumIDs = Set(vm.gridVM.currentAlbumsDisplayed.map(\.id))
        }
      } label: {
        Image(systemName: allVisibleSelected ? "xmark.circle" : "checkmark.circle")
          .font(.system(size: 18))
          .foregroundStyle(.white.opacity(0.8))
      }
      .buttonStyle(.plain)

      // Phase 85: Add to Playlist — menu listing existing playlists + New Playlist option.
      Menu {
        Button {
          let selectedAlbums = vm.gridVM.currentAlbumsDisplayed.filter {
            phoneVM.wpSelectedAlbumIDs.contains($0.id)
          }
          let trackIDs = Set(selectedAlbums.flatMap { $0.tracks.map(\.id) })
          phoneVM.trackIDsForNewPlaylist = trackIDs
          phoneVM.newPlaylistName = ""
          phoneVM.showNewPlaylistAlert = true
        } label: {
          Label(String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle), systemImage: "plus")
        }
        Divider()
        ForEach(Array(vm.library.playlists.dropFirst(2))) { playlist in
          Button {
            let selectedAlbums = vm.gridVM.currentAlbumsDisplayed.filter {
              phoneVM.wpSelectedAlbumIDs.contains($0.id)
            }
            let trackIDs = Set(selectedAlbums.flatMap { $0.tracks.map(\.id) })
            vm.library.addTracks(trackIDs, toPlaylist: playlist.id)
          } label: {
            Text(playlist.name)
          }
        }
      } label: {
        Image(systemName: "text.badge.plus")
          .font(.system(size: 18))
          .foregroundStyle(.white.opacity(0.8))
      }
      .buttonStyle(.plain)

      // Delete.
      Button {
        let selectedAlbums = vm.gridVM.currentAlbumsDisplayed.filter {
          phoneVM.wpSelectedAlbumIDs.contains($0.id)
        }
        phoneVM.albumsToDelete = selectedAlbums
        phoneVM.showDeleteConfirmation = true
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 18))
          .foregroundStyle(.white.opacity(0.8))
      }
      .buttonStyle(.plain)

      // Done.
      Button {
        phoneVM.wpSelectedAlbumIDs = []
      } label: {
        Image(systemName: "checkmark")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.1))
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
}

// MARK: - WPPivotBar

/// WP-style pivot switcher: text buttons with accent underline.
struct WPPivotBar: View {
  @Binding var currentPivot: WPPhoneViewModel.LibraryPivot

  @State private var vm = MadTunesViewModel.shared

  let accentColor: Color

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          ForEach(WPPhoneViewModel.LibraryPivot.allCases) { pivot in
            Button {
              withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
                currentPivot = pivot
              }
            } label: {
              VStack(spacing: 2) {
                Text(pivot.localizedTitle.lowercased())
                  .font(.system(
                    size: currentPivot == pivot ? 16 : 14,
                    weight: currentPivot == pivot ? .bold : .regular
                  ))
                  .foregroundStyle(currentPivot == pivot ? .white : .white.opacity(0.5))
                  .id(pivot)

                Rectangle()
                  .fill(currentPivot == pivot ? accentColor : .clear)
                  .frame(height: 2)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
      }
      .onChange(of: currentPivot) { _, newPivot in
        withAnimation {
          proxy.scrollTo(newPivot, anchor: .center)
        }
      }
    }
  }
}

// MARK: - WPAlbumTilesView

/// Mixed-size tile grid layout inspired by Nokia Music / WP8.
struct WPAlbumTilesView: View {
  // MARK: Internal

  var body: some View {
    GeometryReader { geo in
      let spacing: CGFloat = 4
      let columns = 2
      let tileUnit = (geo.size.width - CGFloat(columns + 1) * spacing) / CGFloat(columns)

      ScrollView(.vertical, showsIndicators: false) {
        // Phase 84: Reorder albums so recently played/imported ones appear first.
        WPTileLayoutView(
          albums: phoneVM.albumsWithRecentFirst(vm.gridVM.currentAlbumsDisplayed),
          tileUnit: tileUnit,
          spacing: spacing,
          phoneVM: phoneVM,
          currentPlaylistID: vm.selectedPlaylistID
        )
        .padding(.horizontal, spacing)
        .padding(.vertical, spacing)
      }
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
}

// MARK: - WPTileLayoutView

/// Produces a mixed-size tile layout using manual VStack/HStack composition.
struct WPTileLayoutView: View {
  // MARK: Internal

  let albums: [Album]
  let tileUnit: CGFloat
  let spacing: CGFloat
  let phoneVM: WPPhoneViewModel
  let currentPlaylistID: UUID?

  var body: some View {
    let tileSpecs = albums.enumerated().map { index, album in
      (album: album, size: phoneVM.tileSizeForAlbum(album, index: index))
    }

    VStack(alignment: .leading, spacing: spacing) {
      // Consume tiles row by row.
      let rows = buildRows(from: tileSpecs)
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .top, spacing: spacing) {
          ForEach(row, id: \.album.id) { item in
            WPTileItemView(
              album: item.album,
              tileSize: item.size,
              tileUnit: tileUnit,
              spacing: spacing,
              currentPlaylistID: currentPlaylistID
            )
          }
        }
      }
    }
  }

  // MARK: Private

  /// Build rows of tiles, each row consuming up to 2 column units.
  private func buildRows(
    from specs: [(album: Album, size: WPPhoneViewModel.TileSize)]
  )
    -> [[(album: Album, size: WPPhoneViewModel.TileSize)]] {
    var rows: [[(album: Album, size: WPPhoneViewModel.TileSize)]] = []
    var i = 0
    while i < specs.count {
      let current = specs[i]
      switch current.size {
      case .large:
        // Large tile takes full row (2×2 → occupies 2 rows visually, handled by height).
        rows.append([current])
        i += 1
      case .medium:
        // Medium tile takes full width (2×1).
        rows.append([current])
        i += 1
      case .small:
        // Try to pair two small tiles in one row.
        if i + 1 < specs.count, specs[i + 1].size == .small {
          rows.append([current, specs[i + 1]])
          i += 2
        } else {
          rows.append([current])
          i += 1
        }
      }
    }
    return rows
  }
}

// MARK: - WPTileItemView

/// A single tile showing album artwork with overlay title.
struct WPTileItemView: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  let album: Album
  let tileSize: WPPhoneViewModel.TileSize
  let tileUnit: CGFloat
  let spacing: CGFloat
  let currentPlaylistID: UUID?

  var body: some View {
    let width: CGFloat = switch tileSize {
    case .large: tileUnit * 2 + spacing
    case .medium: tileUnit * 2 + spacing
    case .small: tileUnit
    }
    let height: CGFloat = switch tileSize {
    case .large: tileUnit * 2 + spacing
    case .medium: tileUnit
    case .small: tileUnit
    }

    // Phase 82: Live tile indicator for currently playing album.
    let isPlayingAlbum: Bool = {
      guard let current = vm.player.currentTrack else { return false }
      return album.allTrackIDsSet.contains(current.id)
    }()

    // Phase 83: Use phoneVM.wpSelectedAlbumIDs (not gridVM.highlightedAlbumIDs)
    // to avoid cross-UI contamination with macOS Grid selection.
    let isSelectionModeActive = phoneVM.isWPSelectionModeActive
    let isSelected = phoneVM.wpSelectedAlbumIDs.contains(album.id)

    Button {
      if isSelectionModeActive {
        if isSelected {
          phoneVM.wpSelectedAlbumIDs.remove(album.id)
        } else {
          phoneVM.wpSelectedAlbumIDs.insert(album.id)
        }
      } else {
        phoneVM.navigationPath.append(
          WPNavigationDestination.albumDetail(album, sourcePlaylistID: currentPlaylistID)
        )
      }
    } label: {
      ZStack(alignment: .bottomLeading) {
        // Artwork.
        LazyAlbumArtworkView(album: album)
          .frame(width: width, height: height)
          .clipped()

        // Title overlay.
        LinearGradient(
          colors: [.clear, .black.opacity(0.7)],
          startPoint: .center,
          endPoint: .bottom
        )

        VStack(alignment: .leading, spacing: 2) {
          Spacer()
          Text(verbatim: album.title)
            .font(.system(size: tileSize == .small ? 11 : 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
          if tileSize != .small {
            Text(verbatim: album.artist)
              .font(.system(size: 11))
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)
          }
        }
        .padding(6)

        if isPlayingAlbum {
          // Live tile badge for playing album. Updating progress once per second.
          TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let progress: Double = {
              guard vm.player.duration > 0 else { return 0 }
              return min(max(vm.player.currentTime / vm.player.duration, 0), 1)
            }()

            VStack {
              HStack {
                ZStack {
                  Circle()
                    .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                    .background(Circle().foregroundStyle(Color.black.opacity(0.6)))
                    .frame(width: 24, height: 24)

                  Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                }
                .overlay(
                  Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                )

                Spacer()
              }
              Spacer()
            }
            .padding(8)
          }
        }

        if isSelected {
          // Selection overlay (WPUI select mode)
          Color.black.opacity(0.25)
            .overlay(
              VStack {
                HStack {
                  Spacer()
                  Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                }
                Spacer()
              }
            )
        }
      }
      .frame(width: width, height: height)
      .clipShape(Rectangle())
    }
    .buttonStyle(.plain)
    .wpTiltEffect()
    .contextMenu {
      AlbumContextMenu(
        albums: [album],
        library: vm.library,
        audioPlayer: vm.player,
        currentPlaylistID: currentPlaylistID,
        onShowTrackInfo: {
          phoneVM.tracksForTrackInfo = album.tracks
          phoneVM.isTrackInfoPresented = true
        },
        onShowDeleteConfirmation: {
          phoneVM.albumsToDelete = [album]
          phoneVM.showDeleteConfirmation = true
        },
        onNewPlaylistWithTracks: { trackIDs in
          phoneVM.trackIDsForNewPlaylist = trackIDs
          phoneVM.newPlaylistName = ""
          phoneVM.showNewPlaylistAlert = true
        }
      )
    }
  }
}

// MARK: - WPArtistListView

/// List of unique artists, each row tappable to drill into artist albums.
struct WPArtistListView: View {
  // MARK: Internal

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(phoneVM.uniqueArtists, id: \.self) { artist in
          Button {
            phoneVM.navigationPath.append(
              WPNavigationDestination.artistDetail(artist)
            )
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: artist)
                  .font(.system(size: 17, weight: .semibold))
                  .foregroundStyle(.white)
                let count = phoneVM.albumsForArtist(artist).count
                Text(verbatim: "\(count) \(count == 1 ? "album" : "albums")")
                  .font(.system(size: 13))
                  .foregroundStyle(.white.opacity(0.5))
              }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
          }
          .buttonStyle(.plain)

          Divider()
            .background(Color.white.opacity(0.1))
        }
      }
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
}

// MARK: - WPTrackListView

/// Simple track list used by both "Tracks" and "Recently Added" pivots.
/// Phase 124: Added swipe-to-remove support for static playlists.
struct WPTrackListView: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
  let tracks: [Track]
  var currentPlaylistID: UUID?
  /// Phase 124: When non-nil, enables swipe-to-remove for this static playlist.
  var currentStaticPlaylistID: UUID?

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(tracks) { track in
          wpTrackRow(track: track)

          Divider()
            .background(Color.white.opacity(0.1))
        }
      }
    }
  }

  @ViewBuilder
  private func wpTrackRow(track: Track) -> some View {
    Button {
      // Play tapped track and set queue to all visible tracks.
      if let idx = tracks.firstIndex(of: track) {
        Task { await vm.player.setQueue(tracks, startingAt: idx) }
      }
    } label: {
      HStack(spacing: 12) {
        // Playing indicator.
        if vm.player.currentTrack?.id == track.id, vm.player.isPlaying {
          Image(systemName: "speaker.wave.2.fill")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 20)
        } else {
          Text(verbatim: track.trackNumber > 0 ? "\(track.trackNumber)" : "")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .frame(width: 20, alignment: .trailing)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: track.title)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .lineLimit(1)
          Text(verbatim: track.artist)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
        }

        Spacer()

        Text(verbatim: formatDuration(track.duration))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.white.opacity(0.4))
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .contextMenu {
      TrackContextMenu(
        tracks: [track],
        library: vm.library,
        audioPlayer: vm.player,
        currentPlaylistID: currentPlaylistID,
        isCurrentTrack: vm.player.currentTrack?.id == track.id,
        onShowTrackInfo: {
          phoneVM.tracksForTrackInfo = [track]
          phoneVM.isTrackInfoPresented = true
        },
        onShowDeleteConfirmation: {
          phoneVM.tracksToDelete = [track]
          phoneVM.showTrackDeleteConfirmation = true
        },
        onNewPlaylistWithTracks: { trackIDs in
          phoneVM.trackIDsForNewPlaylist = trackIDs
          phoneVM.newPlaylistName = ""
          phoneVM.showNewPlaylistAlert = true
        }
      )
    }
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return "\(mins):\(String(format: "%02d", secs))"
  }
}
