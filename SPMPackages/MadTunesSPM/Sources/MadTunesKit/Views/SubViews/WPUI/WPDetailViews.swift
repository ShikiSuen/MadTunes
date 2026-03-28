// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPAlbumDetailView

/// Phase 75: Album detail view pushed via NavigationStack.
/// Shows artwork, album info, and track list.
/// Phase 86: Uses live album lookup to prevent stale-data access after deletion.
struct WPAlbumDetailView: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  let album: Album
  let sourcePlaylistID: UUID?

  /// Phase 86: Live lookup — returns the current album from the library (reflecting deletions),
  /// falling back to the navigation-snapshot only if the album still exists.
  private var currentAlbum: Album {
    if let mainLibraryAlbum = vm.library.albums.first(where: { $0.id == album.id }) {
      return mainLibraryAlbum
    }

    // Phase 139: For playlist-scoped albums (e.g. folder playlists),
    // look up from the source playlist passed at navigation time, not from
    // vm.selectedPlaylistID which may have been reset by WPPlaylistDetailView.onDisappear.
    if let playlistID = sourcePlaylistID,
       let playlist = vm.library.playlists.first(where: { $0.id == playlistID }),
       let scopedAlbum = vm.library.albums(for: playlist).first(where: { $0.id == album.id }) {
      return scopedAlbum
    }

    return album
  }

  var body: some View {
    let liveAlbum = currentAlbum
    // Phase 86: If the album has no tracks left (all deleted), show nothing.
    // The navigation pop is handled centrally by removeTracksFromLibrary.
    if liveAlbum.tracks.isEmpty {
      Color.black.ignoresSafeArea()
    } else {
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 16) {
          // Artwork.
          LazyAlbumArtworkView(album: liveAlbum)
            .frame(width: 200, height: 200)
            .clipShape(.rect)
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            .padding(.top, 16)

          // Album info.
          VStack(spacing: 4) {
            Text(verbatim: liveAlbum.title)
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(.white)
              .multilineTextAlignment(.center)
            Text(verbatim: liveAlbum.artist)
              .font(.system(size: 16))
              .foregroundStyle(.white.opacity(0.7))
            if let year = liveAlbum.year {
              Text(verbatim: "\(year)")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            }
          }
          .padding(.horizontal, 15)

          // Play / Shuffle buttons.
          HStack(spacing: 16) {
            Button {
              Task { await vm.player.setQueue(liveAlbum.tracks, startingAt: 0) }
            } label: {
              Label(
                String(localized: "i18n:WP.Play", bundle: #bundle),
                systemImage: "play.fill"
              )
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 15)
              .padding(.vertical, 10)
              .background(phoneVM.wpAccentColor.color)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
              let shuffled = liveAlbum.tracks.shuffled()
              Task { await vm.player.setQueue(shuffled, startingAt: 0) }
            } label: {
              Label(
                String(localized: "i18n:WP.Shuffle", bundle: #bundle),
                systemImage: "shuffle"
              )
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 15)
              .padding(.vertical, 10)
              .background(Color.white.opacity(0.15))
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
          }
          .padding(.top, 4)

          // Track list.
          Divider().background(Color.white.opacity(0.1))

          WPTrackListView(tracks: liveAlbum.tracks)
            .frame(minHeight: CGFloat(liveAlbum.tracks.count) * 50)
        }
      }
      .background(Color.black.ignoresSafeArea())
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
      #endif
    }
  }
}

// MARK: - WPArtistDetailView

/// Phase 75: Artist detail view showing albums by a specific artist.
struct WPArtistDetailView: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  let artistName: String

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        // Artist header.
        Text(verbatim: artistName)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 15)
          .padding(.top, 16)

        // Albums by this artist as tile rows.
        let albums = phoneVM.albumsForArtist(artistName)
        ForEach(albums) { album in
          Button {
            phoneVM.navigationPath.append(
              WPNavigationDestination.albumDetail(album)
            )
          } label: {
            HStack(spacing: 14) {
              LazyAlbumArtworkView(album: album)
                .frame(width: 60, height: 60)
                .clipShape(.rect)

              VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: album.title)
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                HStack(spacing: 8) {
                  if let year = album.year {
                    Text(verbatim: "\(year)")
                      .font(.system(size: 13))
                      .foregroundStyle(.white.opacity(0.5))
                  }
                  Text(verbatim: "\(album.tracks.count) tracks")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                }
              }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          // Phase 77: Album context menu for artist detail rows.
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

          Divider()
            .background(Color.white.opacity(0.1))
        }
      }
    }
    .background(Color.black.ignoresSafeArea())
    #if !os(macOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.hidden, for: .navigationBar)
    #endif
  }
}

// MARK: - WPPlaylistDetailView

/// Phase 75: Playlist detail view showing tracks in a specific playlist.
/// Phase 76: EditMode support for reorderable playlists (staticList / Favorites).
/// Phase 86: Guards against deleted playlists to prevent stale-data rendering.
/// Phase 124: Unified track select+reorder mode (replaces separate Edit button).
struct WPPlaylistDetailView: View {
  private enum PlaylistDetailContentMode {
    case tracks
    case albums
  }

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  let playlist: Playlist
  @State private var contentMode: PlaylistDetailContentMode = .tracks

  /// Phase 86: Whether this playlist still exists in the library.
  private var playlistExists: Bool {
    vm.library.playlists.contains { $0.id == playlist.id }
  }

  var body: some View {
    // Phase 86: If playlist was deleted, show empty view (nav pop handles the rest).
    if !playlistExists {
      Color.black.ignoresSafeArea()
    } else {
      VStack(spacing: 0) {
        // Header.
        VStack(spacing: 8) {
          HStack {
            Spacer()
            Text(verbatim: currentPlaylist.name)
              .font(.system(size: 24, weight: .bold))
              .foregroundStyle(.white)
            Spacer()
          }
          Text(verbatim: "\(playlistTracks.count) tracks")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))

          // Play / Shuffle / Select buttons.
          HStack(spacing: 16) {
            Button {
              let tracks = playlistTracks
              guard !tracks.isEmpty else { return }
              Task { await vm.player.setQueue(tracks, startingAt: 0) }
            } label: {
              Label(
                String(localized: "i18n:WP.Play", bundle: #bundle),
                systemImage: "play.fill"
              )
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.white)
              .labelStyle(.iconOnly)
              .padding(.horizontal, 15)
              .padding(.vertical, 10)
              .background(phoneVM.wpAccentColor.color)
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
              let tracks = playlistTracks.shuffled()
              guard !tracks.isEmpty else { return }
              Task { await vm.player.setQueue(tracks, startingAt: 0) }
            } label: {
              Label(
                String(localized: "i18n:WP.Shuffle", bundle: #bundle),
                systemImage: "shuffle"
              )
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(.white)
              .labelStyle(.iconOnly)
              .padding(.horizontal, 15)
              .padding(.vertical, 10)
              .background(Color.white.opacity(0.15))
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            if currentPlaylist.kind == .dynamicList {
              Button {
                vm.openPredicateEditor(for: currentPlaylist)
              } label: {
                Label(
                  String(localized: "i18n:Sidebar.EditPredicates", bundle: #bundle),
                  systemImage: "gearshape.2"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .labelStyle(.iconOnly)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
              }
              .buttonStyle(.plain)
            }

            if currentPlaylist.kind == .folderList {
              Button {
                Task {
                  await vm.library.rescanFolderPlaylist(id: currentPlaylist.id)
                }
              } label: {
                Label(
                  String(localized: "i18n:Sidebar.RescanFolder", bundle: #bundle),
                  systemImage: "arrow.clockwise"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .labelStyle(.iconOnly)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
              }
              .buttonStyle(.plain)
            }

            if contentMode == .tracks, !playlistTracks.isEmpty {
              // Phase 123: Sort menu button.
              wpSortMenu

              // Phase 124: Unified track select + reorder toggle button.
              wpTrackSelectButton
            }
          }
          .padding(.top, 4)
        }
        .padding(.vertical, 16)

        // Phase 140: Show pivot for all playlists except All Music.
        wpPlaylistContentPivot

        // Phase 124: Track selection bar (shown when multi-select is active).
        if contentMode == .tracks, phoneVM.isWPTrackSelectionModeActive {
          wpTrackSelectionBar
        }

        Divider().background(Color.white.opacity(0.1))

        // Phase 140: Any non-All Music playlist can switch between track list and album tiles.
        if contentMode == .albums {
          wpPlaylistAlbumTiles
        } else {
          // Track list — selection mode uses List with checkmarks + optional drag handles.
          if phoneVM.isWPTrackSelectionModeActive {
            // Phase 124: Unified selection + reorder mode.
            wpSelectableTrackList
          } else {
            WPTrackListView(
              tracks: playlistTracks,
              currentPlaylistID: playlist.id,
              currentStaticPlaylistID: currentStaticPlaylistID
            )
          }
        }
      }
      .background(Color.black.ignoresSafeArea())
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
      #endif
        .onAppear {
          // Phase 139: Re-set playlist scope on appear so that returning from a
          // pushed album-detail view restores the correct selectedPlaylistID.
          vm.selectedPlaylistID = playlist.id
        }
        .onDisappear {
          // Phase 124: Clear track selection when leaving playlist detail.
          phoneVM.wpSelectedTrackIDs = []
          // Phase 139: Reset WPUI library scope back to All Music
          // to avoid leaking playlist-specific selectedPlaylistID into Library pivots.
          vm.selectedPlaylistID = vm.library.playlists.first?.id
        }
    } // Phase 86: end of `if playlistExists` else branch.
  }

  /// Look up the current playlist from the library to reflect reorder changes.
  private var currentPlaylist: Playlist {
    vm.library.playlists.first { $0.id == playlist.id } ?? playlist
  }

  /// Phase 123: Apply compound sort for dynamic playlists on top of base tracks.
  /// Static playlists already have persistent sort baked into trackIDs.
  /// Phase 140: Uses filteredTracksBase to honour Column Browser filters.
  private var playlistTracks: [Track] {
    let baseTracks = vm.filteredTracksBase
    let criteria = vm.tableVM.tableSortCriteria
    if !criteria.isEmpty {
      return vm.tableVM.sortedTracks(baseTracks, by: criteria)
    }
    return baseTracks
  }

  /// Phase 140: Album-tiles data source for playlist detail.
  /// Uses currentAlbumsDisplayed to honour Column Browser filters.
  private var playlistAlbums: [Album] {
    let albums = vm.gridVM.currentAlbumsDisplayed
    return phoneVM.albumsWithRecentFirst(albums)
  }

  /// Phase 76: Whether this playlist supports drag-reorder.
  private var canReorder: Bool {
    guard let index = vm.library.playlists.firstIndex(where: { $0.id == playlist.id }) else {
      return false
    }
    if index == 0 { return false } // All Music is never reorderable.
    let pl = vm.library.playlists[index]
    return pl.kind == .staticList || (pl.kind == .system && index == 1)
  }

  /// Phase 124: Static playlist ID (if current playlist is static), for swipe-to-remove.
  private var currentStaticPlaylistID: UUID? {
    let pl = currentPlaylist
    guard pl.kind == .staticList else { return nil }
    return pl.id
  }

  /// Phase 123: Sort fields available in the WPUI sort menu.
  private static let sortableColumns: [TableColumnType] = TableColumnType.allCases.filter(\.isHidable)

  /// Phase 123: Whether the current playlist uses compound sort (dynamic/All Music) vs persistent sort (static).
  private var isCompoundSort: Bool {
    vm.tableVM.isCompoundSortAllowed
  }

  // MARK: - Phase 124: Unified Track Select + Reorder Button

  @ViewBuilder private var wpTrackSelectButton: some View {
    Button {
      if phoneVM.isWPTrackSelectionModeActive {
        phoneVM.wpSelectedTrackIDs = []
      } else if let firstID = playlistTracks.first?.id {
        phoneVM.wpSelectedTrackIDs = [firstID]
      }
    } label: {
      let labelText: String = phoneVM.isWPTrackSelectionModeActive
        ? String(localized: "i18n:WP.Menu.ExitSelect", bundle: #bundle)
        : String(localized: "i18n:WP.Menu.SelectTracks", bundle: #bundle)
      Label(
        labelText,
        systemImage: phoneVM.isWPTrackSelectionModeActive
          ? "xmark.circle"
          : "checkmark.circle"
      )
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .labelStyle(.iconOnly)
      .padding(.horizontal, 15)
      .padding(.vertical, 10)
      .background(
        phoneVM.isWPTrackSelectionModeActive
          ? phoneVM.wpAccentColor.color
          : Color.white.opacity(0.15)
      )
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Phase 139: Folder Playlist Albums/Tracks Pivot

  @ViewBuilder private var wpPlaylistContentPivot: some View {
    HStack(spacing: 20) {
      Button {
        contentMode = .tracks
      } label: {
        VStack(spacing: 2) {
          Text(WPPhoneViewModel.LibraryPivot.tracks.localizedTitle.lowercased())
            .font(.system(size: contentMode == .tracks ? 16 : 14, weight: contentMode == .tracks ? .bold : .regular))
            .foregroundStyle(contentMode == .tracks ? .white : .white.opacity(0.5))

          Rectangle()
            .fill(contentMode == .tracks ? phoneVM.wpAccentColor.color : .clear)
            .frame(height: 2)
        }
      }
      .buttonStyle(.plain)

      Button {
        contentMode = .albums
        phoneVM.wpSelectedTrackIDs = []
      } label: {
        VStack(spacing: 2) {
          Text(WPPhoneViewModel.LibraryPivot.albums.localizedTitle.lowercased())
            .font(.system(size: contentMode == .albums ? 16 : 14, weight: contentMode == .albums ? .bold : .regular))
            .foregroundStyle(contentMode == .albums ? .white : .white.opacity(0.5))

          Rectangle()
            .fill(contentMode == .albums ? phoneVM.wpAccentColor.color : .clear)
            .frame(height: 2)
        }
      }
      .buttonStyle(.plain)

      Spacer(minLength: 0)

      // Phase 140: Column Browser entry in the pivot bar.
      Button {
        phoneVM.isColumnBrowserPresented = true
      } label: {
        Image(
          systemName: vm.isColumnBrowserFiltering
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        )
        .font(.system(size: 18))
        .foregroundStyle(
          vm.isColumnBrowserFiltering
            ? phoneVM.wpAccentColor.color
            : .white.opacity(0.5)
        )
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 15)
    .padding(.bottom, 8)
  }

  // MARK: - Phase 140: Playlist Album Tiles

  @ViewBuilder private var wpPlaylistAlbumTiles: some View {
    GeometryReader { geo in
      let spacing: CGFloat = 4
      let columns = 2
      let tileUnit = (geo.size.width - CGFloat(columns + 1) * spacing) / CGFloat(columns)

      ScrollView(.vertical, showsIndicators: false) {
        WPTileLayoutView(
          albums: playlistAlbums,
          tileUnit: tileUnit,
          spacing: spacing,
          phoneVM: phoneVM,
          currentPlaylistID: playlist.id
        )
        .padding(.horizontal, spacing)
        .padding(.vertical, spacing)
      }
    }
  }

  // MARK: - Phase 124: Track Selection Bar

  @ViewBuilder private var wpTrackSelectionBar: some View {
    let selectionCount = phoneVM.wpSelectedTrackIDs.count
    let allVisibleSelected = selectionCount > 0
      && selectionCount == playlistTracks.count

    HStack(spacing: 16) {
      // Selection count.
      Text(verbatim: "\(selectionCount)")
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)

      Spacer(minLength: 0)

      // Select All / Deselect All.
      Button {
        if allVisibleSelected {
          phoneVM.wpSelectedTrackIDs = []
        } else {
          phoneVM.wpSelectedTrackIDs = Set(playlistTracks.map(\.id))
        }
      } label: {
        Image(systemName: allVisibleSelected ? "xmark.circle" : "checkmark.circle")
          .font(.system(size: 18))
          .foregroundStyle(.white.opacity(0.8))
      }
      .buttonStyle(.plain)

      // Add to Playlist.
      Menu {
        Button {
          phoneVM.trackIDsForNewPlaylist = phoneVM.wpSelectedTrackIDs
          phoneVM.newPlaylistName = ""
          phoneVM.showNewPlaylistAlert = true
        } label: {
          Label(String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle), systemImage: "plus")
        }
        Divider()
        ForEach(Array(vm.library.playlists.dropFirst(2).filter { $0.kind == .staticList })) { playlist in
          Button {
            vm.library.addTracks(phoneVM.wpSelectedTrackIDs, toPlaylist: playlist.id)
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

      // Remove from Playlist (static playlists only).
      if let staticID = currentStaticPlaylistID {
        Button(role: .destructive) {
          vm.library.removeTracksFromPlaylist(phoneVM.wpSelectedTrackIDs, playlistID: staticID)
          vm.invalidateSearchCacheForRemovedTracks(phoneVM.wpSelectedTrackIDs)
          phoneVM.wpSelectedTrackIDs = []
        } label: {
          Image(systemName: "minus.circle")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
      }

      // Done.
      Button {
        phoneVM.wpSelectedTrackIDs = []
      } label: {
        Image(systemName: "checkmark")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.1))
  }

  // MARK: - Phase 124: Selectable Track List (with optional drag-reorder)

  /// Phase 124: When `canReorder`, uses List with .onMove for drag handles;
  /// otherwise uses ScrollView + LazyVStack for non-reorderable playlists.
  @ViewBuilder private var wpSelectableTrackList: some View {
    #if !(canImport(AppKit) && !canImport(UIKit))
    if canReorder {
      List {
        ForEach(playlistTracks) { track in
          wpSelectableRow(track: track)
            .listRowBackground(Color.black)
            .padding(.horizontal)
            .listRowInsets(.init())
        }
        .onMove { source, destination in
          let ids = source.map { playlistTracks[$0].id }
          vm.library.moveTracks(ids, inPlaylist: playlist.id, toIndex: destination)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .environment(\.editMode, .constant(.active))
    } else {
      wpSelectableScrollList
    }
    #else
    wpSelectableScrollList
    #endif
  }

  /// Phase 124: ScrollView-based selectable track list (no drag handles).
  @ViewBuilder private var wpSelectableScrollList: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(playlistTracks) { track in
          wpSelectableRow(track: track)

          Divider()
            .background(Color.white.opacity(0.1))
        }
      }
    }
  }

  /// Phase 124: A single selectable track row with checkmark + context menu.
  @ViewBuilder
  private func wpSelectableRow(track: Track) -> some View {
    let isSelected = phoneVM.wpSelectedTrackIDs.contains(track.id)
    Button {
      if isSelected {
        phoneVM.wpSelectedTrackIDs.remove(track.id)
      } else {
        phoneVM.wpSelectedTrackIDs.insert(track.id)
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? phoneVM.wpAccentColor.color : .white.opacity(0.3))
          .frame(width: 24)

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
      }
      .padding(.vertical, 8)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .contextMenu {
      TrackContextMenu(
        tracks: phoneVM.wpSelectedTrackIDs.isEmpty
          ? [track]
          : playlistTracks.filter { phoneVM.wpSelectedTrackIDs.contains($0.id) },
        library: vm.library,
        audioPlayer: vm.player,
        currentPlaylistID: playlist.id,
        onShowTrackInfo: {
          phoneVM.tracksForTrackInfo = phoneVM.wpSelectedTrackIDs.isEmpty
            ? [track]
            : playlistTracks.filter { phoneVM.wpSelectedTrackIDs.contains($0.id) }
          phoneVM.isTrackInfoPresented = true
        },
        onShowDeleteConfirmation: {
          phoneVM.tracksToDelete = phoneVM.wpSelectedTrackIDs.isEmpty
            ? [track]
            : playlistTracks.filter { phoneVM.wpSelectedTrackIDs.contains($0.id) }
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

  /// Phase 123: Sort menu button styled for Metro UI.
  @ViewBuilder private var wpSortMenu: some View {
    Menu {
      ForEach(Self.sortableColumns) { column in
        let indicator = vm.tableVM.sortIndicator(for: column)
        Button {
          // Phase 124: Exit selection mode when sorting.
          if phoneVM.isWPTrackSelectionModeActive {
            phoneVM.wpSelectedTrackIDs = []
          }
          vm.tableVM.setTableSort(column: column)
        } label: {
          if let indicator {
            Text(verbatim: column.localizedName + indicator)
          } else {
            Text(verbatim: column.localizedName)
          }
        }
      }

      // Phase 123: Clear Sort for dynamic playlists only.
      if isCompoundSort, !vm.tableVM.tableSortCriteria.isEmpty {
        Divider()
        Button(role: .destructive) {
          vm.tableVM.clearCompoundSortAndPersist()
        } label: {
          Label(
            String(localized: "i18n:WP.Sort.Clear", bundle: #bundle),
            systemImage: "xmark.circle"
          )
        }
      }
    } label: {
      Label(
        String(localized: "i18n:WP.Sort", bundle: #bundle),
        systemImage: "arrow.up.arrow.down"
      )
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .labelStyle(.iconOnly)
      .padding(.horizontal, 15)
      .padding(.vertical, 10)
      .background(
        vm.tableVM.isSortActive
          ? phoneVM.wpAccentColor.color
          : Color.white.opacity(0.15)
      )
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .help(String(localized: "i18n:WP.Sort", bundle: #bundle))
  }
}
