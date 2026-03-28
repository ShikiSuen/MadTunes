// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - DataSourceMenu

/// Phase 135: [Task 5] Data Source Menu reusable in Predicate Editor, etc.
struct DataSourceMenu: View {
  // MARK: Lifecycle

  init(playlist: Playlist, library: any MusicLibraryProviding) {
    self.playlist = playlist
    self.library = library
  }

  // MARK: Internal

  var body: some View {
    let folderPlaylists = library.folderPlaylistsAsDataSources()
    Menu {
      Button {
        library.clearAllSourceFolderPlaylists(playlistID: playlist.id)
      } label: {
        let isSelected = playlist.sourceFolderPlaylistIDSet.isEmpty
        Label(
          String(localized: "i18n:Sidebar.DataSource.AllMusic", bundle: #bundle),
          systemImage: isSelected ? "checkmark" : ""
        )
      }
      if !folderPlaylists.isEmpty {
        Divider()
        ForEach(folderPlaylists) { folderPlaylist in
          Button {
            library.toggleSourceFolderPlaylist(
              playlistID: playlist.id,
              folderPlaylistID: folderPlaylist.id
            )
          } label: {
            let isSelected = playlist.sourceFolderPlaylistIDSet.contains(folderPlaylist.id)
            Label(
              folderPlaylist.name,
              systemImage: isSelected ? "checkmark" : ""
            )
          }
        }
      }
    } label: {
      // `cylinder.split.1x2` 是資料庫的代表 icon。`externaldrive` 反而會鬧歧義。
      Label(
        String(localized: "i18n:Sidebar.DataSource", bundle: #bundle),
        systemImage: "cylinder.split.1x2"
      )
    }
  }

  // MARK: Private

  private let playlist: Playlist
  private let library: any MusicLibraryProviding
}
