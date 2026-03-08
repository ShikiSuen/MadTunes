// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

/// Sidebar listing the Library (All Music) and user-created playlists.
struct SidebarView: View {
  var library: MusicLibrary
  @Binding var selectedPlaylistID: UUID?
  @State private var isAddingPlaylist = false
  @State private var newPlaylistName = ""

  var body: some View {
    List(selection: $selectedPlaylistID) {
      Section("Library") {
        if let allMusic = library.playlists.first {
          Label(allMusic.name, systemImage: "music.note.list")
            .tag(allMusic.id)
        }
      }

      Section("Playlists") {
        ForEach(Array(library.playlists.dropFirst())) { playlist in
          Label(playlist.name, systemImage: "music.note.list")
            .tag(playlist.id)
        }
        .onDelete { indexSet in
          // Offset by 1 because dropFirst() removes the "All Music" entry.
          for index in indexSet {
            library.removePlaylist(at: index + 1)
          }
        }

        if isAddingPlaylist {
          TextField("Playlist Name", text: $newPlaylistName)
            .onSubmit {
              if !newPlaylistName.isEmpty {
                library.addPlaylist(name: newPlaylistName)
                newPlaylistName = ""
              }
              isAddingPlaylist = false
            }
        }

        Button {
          isAddingPlaylist = true
        } label: {
          Label("New Playlist", systemImage: "plus")
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("MadTunes")
  }
}
