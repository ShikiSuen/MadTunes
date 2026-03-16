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
      // Phase 78: Pivot bar + Column Browser filter button.
      HStack(spacing: 0) {
        WPPivotBar(
          currentPivot: $pvm.currentPivot,
          accentColor: phoneVM.wpAccentColor.color
        )

        // Column Browser filter button.
        Button {
          phoneVM.isColumnBrowserPresented = true
        } label: {
          Image(
            systemName: vm.isColumnBrowserFiltering
              ? "line.3.horizontal.decrease.circle.fill"
              : "line.3.horizontal.decrease.circle"
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

        // Import menu (shown when library has content)
        if !vm.library.tracks.isEmpty {
          Menu {
            Button {
              vm.isFileImporterPresented = true
            } label: {
              Label(
                String(localized: "i18n:Import.ImportFiles", bundle: #bundle),
                systemImage: "music.note"
              )
            }
            Button {
              vm.isFolderImporterPresented = true
            } label: {
              Label(
                String(localized: "i18n:Import.ImportFolder", bundle: #bundle),
                systemImage: "folder"
              )
            }
          } label: {
            Image(systemName: "square.and.arrow.down")
              .font(.system(size: 20))
              .foregroundStyle(.white.opacity(0.5))
          }
          .buttonStyle(.plain)
          .padding(.trailing, 16)
        }
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

// MARK: - WPPivotBar

/// WP-style pivot switcher: text buttons with accent underline.
struct WPPivotBar: View {
  @Binding var currentPivot: WPPhoneViewModel.LibraryPivot

  let accentColor: Color

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          ForEach(WPPhoneViewModel.LibraryPivot.allCases) { pivot in
            Button {
              withAnimation(.easeInOut(duration: 0.2)) {
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
        WPTileLayoutView(
          albums: vm.gridVM.currentAlbumsDisplayed,
          tileUnit: tileUnit,
          spacing: spacing,
          phoneVM: phoneVM
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
              spacing: spacing
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

    Button {
      phoneVM.navigationPath.append(
        WPNavigationDestination.albumDetail(album)
      )
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
struct WPTrackListView: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
  let tracks: [Track]
  var currentPlaylistID: UUID?

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(tracks) { track in
          Button {
            // Play tapped track and set queue to all visible tracks.
            if let idx = tracks.firstIndex(of: track) {
              vm.player.setQueue(tracks, startingAt: idx)
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

          Divider()
            .background(Color.white.opacity(0.1))
        }
      }
    }
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return "\(mins):\(String(format: "%02d", secs))"
  }
}
