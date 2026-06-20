// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPPlaylistsSection

/// Phase 75: Playlists section of the Panorama Hub.
/// Shows all playlists as full-width tappable rows.
/// Phase 78: Added create/rename/delete playlist management.
/// Phase 122: Drag-reorder for user playlists via List + .onMove.
struct WPPlaylistsSection: View {
  // MARK: Internal

  var body: some View {
    List {
      // System playlists (All Music, Favorites) — non-reorderable.
      Group {
        if let allMusic = vm.library.playlists.first {
          playlistRow(allMusic)
        }
        if vm.library.playlists.count > 1 {
          playlistRow(vm.library.playlists[1])
        }
      }
      .listRowBackground(Color.clear)
      .listRowSeparatorTint(.white.opacity(0.1))
      .padding(.horizontal)
      .listRowInsets(.init())

      // Phase 122: User playlists with drag-reorder.
      ForEach(userPlaylists) { playlist in
        playlistRow(playlist)
          .contextMenu {
            Section {
              if playlist.kind == .dynamicList {
                Button {
                  vm.attemptToOpenPredicateEditorAsync(for: playlist)
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.EditPredicates", bundle: #bundle),
                    systemImage: "gearshape.2"
                  )
                }
                // Phase 135: Data source submenu for dynamic playlists.
                DataSourceMenu(playlist: playlist, library: vm.library)
              }
              if playlist.kind == .folderList {
                Button {
                  Task {
                    await vm.library.rescanFolderPlaylist(id: playlist.id)
                  }
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.RescanFolder", bundle: #bundle),
                    systemImage: "arrow.clockwise"
                  )
                }
              }
              Button {
                phoneVM.renamePlaylistName = playlist.name
                phoneVM.renamePlaylistID = playlist.id
                phoneVM.isRenamePlaylistAlertPresented = true
              } label: {
                Label(String(localized: "i18n:Common.Rename", bundle: #bundle), systemImage: "pencil")
              }
              if playlist.kind != .folderList {
                Button {
                  vm.library.duplicatePlaylist(id: playlist.id)
                } label: {
                  Label(String(localized: "i18n:Sidebar.DuplicatePlaylist", bundle: #bundle), systemImage: "doc.on.doc")
                }
              }
            } header: {
              Text(playlist.kind.localizedDescription)
            }
            Divider()
            Button(role: .destructive) {
              if vm.selectedPlaylistID == playlist.id {
                vm.selectedPlaylistID = vm.library.playlists.first?.id
              }
              if playlist.kind == .folderList {
                vm.library.removeFolderPlaylist(id: playlist.id)
              } else {
                vm.library.removePlaylist(id: playlist.id)
              }
              phoneVM.popNavigationIfDataInvalid(library: vm.library)
            } label: {
              Label(String(localized: "i18n:Common.Delete", bundle: #bundle), systemImage: "trash")
            }
          }
          .listRowBackground(Color.clear)
          .padding(.horizontal)
          .listRowInsets(.init())
          .listRowSeparatorTint(.white.opacity(0.1))
      }
      .onMove { source, destination in
        vm.library.moveUserPlaylists(fromOffsets: source, toOffset: destination)
      }

      // Phase 78: Create new playlist button.
      newPlaylistMenu
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    #if !os(macOS)
      .environment(\.editMode, .constant(.active))
    #endif
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  /// Phase 122: User playlists (index 2+), matching SidebarView's convention.
  private var userPlaylists: [Playlist] {
    Array(vm.library.playlists.dropFirst(2))
  }

  @ViewBuilder private var newPlaylistMenu: some View {
    Menu {
      Button {
        vm.playlistCreationAlertText = ""
        vm.playlistCreationAlertKind = .staticPlaylist
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewStaticPlaylist", bundle: #bundle),
          systemImage: "music.note.list"
        )
      }
      Button {
        vm.playlistCreationAlertText = ""
        vm.playlistCreationAlertKind = .dynamicPlaylist
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewDynamicPlaylist", bundle: #bundle),
          systemImage: "gearshape.2"
        )
      }
      Divider()
      Button {
        vm.isImporterForFolderPlaylistPresented = true
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewFolderPlaylist", bundle: #bundle),
          systemImage: "folder.fill"
        )
      }
    } label: {
      HStack(spacing: 14) {
        Image(systemName: "plus")
          .font(.system(size: 20))
          .foregroundStyle(phoneVM.wpAccentColor.color)
          .frame(width: 28)
        Text(String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle))
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private func playlistRow(_ playlist: Playlist) -> some View {
    let trackCount = playlist.kind == .folderList
      ? (vm.library.folderPlaylistTracks[playlist.id]?.count ?? 0)
      : playlist.trackIDs.count
    return HStack(spacing: 14) {
      Image(systemName: iconForPlaylist(playlist))
        .font(.system(size: 20))
        .foregroundStyle(phoneVM.wpAccentColor.color)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(verbatim: playlist.name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
          // Phase 158: Show warning icon for failed folder playlists.
          if playlist.kind == .folderList,
             vm.library.sandboxHealthReport?.failedFolderPlaylistIDs.contains(playlist.id) == true {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.yellow)
              .font(.caption2)
          }
        }
        Text("i18n:Unit:Track:\(trackCount)", bundle: #bundle)
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.5))
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
    .onTapGesture {
      // Phase 123: Set selectedPlaylistID so AlbumTableViewModel sort infrastructure works.
      vm.selectedPlaylistID = playlist.id
      phoneVM.navigationPath.append(
        WPNavigationDestination.playlistDetail(playlist)
      )
    }
  }

  /// Phase 135: Delegate to Playlist.icon4SFSymbols(idx:).
  private func iconForPlaylist(_ playlist: Playlist) -> String {
    let idx = vm.library.playlists.firstIndex(where: { $0.id == playlist.id })
    return playlist.icon4SFSymbols(idx: idx)
  }
}
