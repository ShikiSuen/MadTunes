// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPPlaylistsSection

/// Phase 75: Playlists section of the Panorama Hub.
/// Shows all playlists as full-width tappable rows.
/// Phase 78: Added create/rename/delete playlist management.
struct WPPlaylistsSection: View {
  // MARK: Internal

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(vm.library.playlists) { playlist in
          Button {
            phoneVM.navigationPath.append(
              WPNavigationDestination.playlistDetail(playlist)
            )
          } label: {
            HStack(spacing: 14) {
              Image(systemName: iconForPlaylist(playlist))
                .font(.system(size: 20))
                .foregroundStyle(phoneVM.wpAccentColor.color)
                .frame(width: 28)

              VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: playlist.name)
                  .font(.system(size: 17, weight: .semibold))
                  .foregroundStyle(.white)
                Text("i18n:Unit:Track:\(playlist.trackIDs.count)", bundle: #bundle)
                  .font(.system(size: 13))
                  .foregroundStyle(.white.opacity(0.5))
              }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .frame(minHeight: 44)
          // Phase 78: Context menu for user-created playlists (rename/delete).
          .contextMenu {
            if isUserPlaylist(playlist) {
              if playlist.kind == .dynamicList {
                Button {
                  phoneVM.predicateEditorPlaylist = playlist
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.EditPredicates", bundle: #bundle),
                    systemImage: "gearshape.2"
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
              Button(role: .destructive) {
                // Phase 86: Reset selectedPlaylistID if pointing to the deleted playlist,
                // and pop navigation to prevent stale playlist detail views.
                if vm.selectedPlaylistID == playlist.id {
                  vm.selectedPlaylistID = vm.library.playlists.first?.id
                }
                vm.library.removePlaylist(id: playlist.id)
                phoneVM.popNavigationIfDataInvalid(library: vm.library)
              } label: {
                Label(String(localized: "i18n:Common.Delete", bundle: #bundle), systemImage: "trash")
              }
            }
          }

          Divider()
            .background(Color.white.opacity(0.1))
        }

        // Phase 78: Create new playlist button.
        Menu {
          Button {
            phoneVM.createPlaylistName = ""
            phoneVM.createPlaylistIsDynamic = false
            phoneVM.isCreatePlaylistAlertPresented = true
          } label: {
            Label(
              String(localized: "i18n:Sidebar.NewStaticPlaylist", bundle: #bundle),
              systemImage: "music.note.list"
            )
          }
          Button {
            phoneVM.createPlaylistName = ""
            phoneVM.createPlaylistIsDynamic = true
            phoneVM.isCreatePlaylistAlertPresented = true
          } label: {
            Label(
              String(localized: "i18n:Sidebar.NewDynamicPlaylist", bundle: #bundle),
              systemImage: "gearshape.2"
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
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 8)
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  private func iconForPlaylist(_ playlist: Playlist) -> String {
    if let idx = vm.library.playlists.firstIndex(where: { $0.id == playlist.id }) {
      if idx == 0 { return "music.note.list" }
      if idx == 1 { return "heart.fill" }
    }
    return playlist.kind == .dynamicList ? "gearshape.2" : "music.note"
  }

  /// Phase 78: Whether a playlist is user-created (not system playlists at index 0/1).
  private func isUserPlaylist(_ playlist: Playlist) -> Bool {
    guard let idx = vm.library.playlists.firstIndex(where: { $0.id == playlist.id }) else {
      return false
    }
    return idx >= 2
  }
}
