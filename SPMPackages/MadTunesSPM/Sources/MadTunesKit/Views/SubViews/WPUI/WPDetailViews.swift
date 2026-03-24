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

  /// Phase 86: Live lookup — returns the current album from the library (reflecting deletions),
  /// falling back to the navigation-snapshot only if the album still exists.
  private var currentAlbum: Album {
    vm.library.albums.first { $0.id == album.id } ?? album
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
          .padding(.horizontal, 20)

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
              .padding(.horizontal, 20)
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
              .padding(.horizontal, 20)
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
          .padding(.horizontal, 20)
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
            .padding(.horizontal, 20)
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
struct WPPlaylistDetailView: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM
  #if !(canImport(AppKit) && !canImport(UIKit))
  @State private var editMode: EditMode = .inactive
  #endif

  let playlist: Playlist

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
          Text(verbatim: "\(currentPlaylist.trackIDs.count) tracks")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))

          // Play / Shuffle / Edit buttons.
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
              .padding(.horizontal, 20)
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
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
              .background(Color.white.opacity(0.15))
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            #if !(canImport(AppKit) && !canImport(UIKit))
            if canReorder {
              Button {
                withAnimation {
                  editMode = editMode == .active ? .inactive : .active
                }
              } label: {
                Text(
                  editMode == .active
                    ? String(localized: "i18n:Common.Done", bundle: #bundle)
                    : String(localized: "i18n:Common.Edit", bundle: #bundle)
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                  editMode == .active
                    ? phoneVM.wpAccentColor.color
                    : Color.white.opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
              }
              .buttonStyle(.plain)
            }
            #endif

            if currentPlaylist.kind == .dynamicList {
              Button {
                vm.openPredicateEditor(for: currentPlaylist)
              } label: {
                Image(systemName: "gearshape.2")
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(.white)
                  .padding(10)
                  .background(Color.white.opacity(0.15))
                  .clipShape(RoundedRectangle(cornerRadius: 6))
              }
              .buttonStyle(.plain)
              .help(String(localized: "i18n:Sidebar.EditPredicates", bundle: #bundle))
            }
          }
          .padding(.top, 4)
        }
        .padding(.vertical, 16)

        Divider().background(Color.white.opacity(0.1))

        // Track list — use List with .onMove when in edit mode for reordering.
        #if !(canImport(AppKit) && !canImport(UIKit))
        if editMode == .active {
          List {
            ForEach(playlistTracks) { track in
              WPEditableTrackRow(track: track, isPlaying: vm.player.currentTrack?.id == track.id && vm.player.isPlaying)
            }
            .onMove { source, destination in
              let ids = source.map { playlistTracks[$0].id }
              vm.library.moveTracks(ids, inPlaylist: playlist.id, toIndex: destination)
            }
            .listRowBackground(Color.black)
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
          .environment(\.editMode, .constant(.active))
        } else {
          WPTrackListView(tracks: playlistTracks, currentPlaylistID: playlist.id)
        }
        #else
        WPTrackListView(tracks: playlistTracks, currentPlaylistID: playlist.id)
        #endif
      }
      .background(Color.black.ignoresSafeArea())
      #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
      #endif
    } // Phase 86: end of `if playlistExists` else branch.
  }

  /// Look up the current playlist from the library to reflect reorder changes.
  private var currentPlaylist: Playlist {
    vm.library.playlists.first { $0.id == playlist.id } ?? playlist
  }

  private var playlistTracks: [Track] {
    vm.library.tracks(for: currentPlaylist)
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
}

// MARK: - WPEditableTrackRow

/// Phase 76: A simplified track row for the edit-mode List, styled for dark Metro theme.
private struct WPEditableTrackRow: View {
  let track: Track
  let isPlaying: Bool

  var body: some View {
    HStack(spacing: 12) {
      if isPlaying {
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
    }
  }
}
