// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

/// Sidebar listing the Library (All Music) and user-created playlists.
struct SidebarView: View {
  // MARK: Lifecycle

  init(
    library: MusicLibrary,
    selectedPlaylistID: Binding<UUID?>
  ) {
    self.library = library
    self._selectedPlaylistID = selectedPlaylistID
  }

  // MARK: Internal

  var body: some View {
    List(selection: $selectedPlaylistID) {
      Section(String(localized: "i18n:Sidebar.Sections.Library", bundle: #bundle)) {
        if let allMusic = library.playlists.first {
          Label(allMusic.name, systemImage: "music.note.list")
            .tag(allMusic.id)
        }
        // Favorites 專用列（心形圖示）
        if library.playlists.count > 1 {
          let favorites = library.playlists[1]
          Label(favorites.name, systemImage: "heart.fill")
            .tag(favorites.id)
        }
      }

      // Phase 116: Dynamic playlists section.
      Section(String(localized: "i18n:Sidebar.Sections.DynamicPlaylists", bundle: #bundle)) {
        ForEach(dynamicPlaylists) { playlist in
          Label(playlist.name, systemImage: "gearshape.2")
            .tag(playlist.id)
            .contextMenu {
              Button {
                alertText = playlist.name
                alertKind = .rename(playlist.id)
              } label: {
                Label(String(localized: "i18n:Common.Rename", bundle: #bundle), systemImage: "pencil")
              }
              Button(role: .destructive) {
                if selectedPlaylistID == playlist.id {
                  selectedPlaylistID = library.playlists.first?.id
                }
                library.removePlaylist(id: playlist.id)
              } label: {
                Label(String(localized: "i18n:Common.Delete", bundle: #bundle), systemImage: "trash")
              }
            }
        }
        .onDelete { indexSet in
          let playlists = dynamicPlaylists
          for index in indexSet {
            let playlist = playlists[index]
            if selectedPlaylistID == playlist.id {
              selectedPlaylistID = library.playlists.first?.id
            }
            library.removePlaylist(id: playlist.id)
          }
        }

        Button {
          alertText = ""
          alertKind = .newDynamicPlaylist
        } label: {
          Label(
            String(localized: "i18n:Sidebar.NewDynamicPlaylist", bundle: #bundle),
            systemImage: "plus"
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonBorderShape(.capsule)
        .buttonStyle(.borderedProminent)
      }

      Section(String(localized: "i18n:Sidebar.Sections.Playlists", bundle: #bundle)) {
        ForEach(staticPlaylists) { playlist in
          Label(playlist.name, systemImage: "music.note.list")
            .tag(playlist.id)
            .contextMenu {
              Button {
                alertText = playlist.name
                alertKind = .rename(playlist.id)
              } label: {
                Label(String(localized: "i18n:Common.Rename", bundle: #bundle), systemImage: "pencil")
              }
              Button(role: .destructive) {
                if selectedPlaylistID == playlist.id {
                  selectedPlaylistID = library.playlists.first?.id
                }
                library.removePlaylist(id: playlist.id)
              } label: {
                Label(String(localized: "i18n:Common.Delete", bundle: #bundle), systemImage: "trash")
              }
            }
        }
        .onDelete { indexSet in
          let playlists = staticPlaylists
          for index in indexSet {
            let playlist = playlists[index]
            if selectedPlaylistID == playlist.id {
              selectedPlaylistID = library.playlists.first?.id
            }
            library.removePlaylist(id: playlist.id)
          }
        }

        Button {
          alertText = ""
          alertKind = .newPlaylist
        } label: {
          Label(
            String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle),
            systemImage: "plus"
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonBorderShape(.capsule)
        .buttonStyle(.borderedProminent)
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("MadTunes")
    .alert(alertTitle, isPresented: alertIsPresented) {
      TextField(alertPlaceholder, text: $alertText)
      Button(alertConfirmLabel) {
        commitAlert()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
  }

  // MARK: Private

  private enum AlertKind: Identifiable {
    case newPlaylist
    case newDynamicPlaylist
    case rename(UUID)

    // MARK: Internal

    var id: String {
      switch self {
      case .newPlaylist: return "new"
      case .newDynamicPlaylist: return "newDynamic"
      case let .rename(id): return id.uuidString
      }
    }
  }

  @Binding private var selectedPlaylistID: UUID?
  // Alert state — shared across both "New Playlist" and "Rename"
  @State private var alertKind: AlertKind?
  @State private var alertText = ""

  private var library: MusicLibrary

  /// Phase 116: User-created dynamic playlists.
  private var dynamicPlaylists: [Playlist] {
    library.playlists.dropFirst(2).filter { $0.kind == .dynamicList }
  }

  /// Phase 116: User-created static playlists.
  private var staticPlaylists: [Playlist] {
    library.playlists.dropFirst(2).filter { $0.kind == .staticList }
  }

  // MARK: - Alert helpers

  private var alertTitle: String {
    switch alertKind {
    case .newPlaylist: return String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle)
    case .newDynamicPlaylist: return String(localized: "i18n:Sidebar.Alert.NewDynamicPlaylistTitle", bundle: #bundle)
    case .rename: return String(localized: "i18n:Sidebar.Alert.RenamePlaylistTitle", bundle: #bundle)
    case nil: return ""
    }
  }

  private var alertPlaceholder: String {
    switch alertKind {
    case .newDynamicPlaylist, .newPlaylist:
      return String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle)
    case .rename: return String(localized: "i18n:Sidebar.Alert.NewNamePlaceholder", bundle: #bundle)
    case nil: return ""
    }
  }

  private var alertConfirmLabel: String {
    switch alertKind {
    case .newDynamicPlaylist, .newPlaylist:
      return String(localized: "i18n:Common.Create", bundle: #bundle)
    case .rename: return String(localized: "i18n:Common.Rename", bundle: #bundle)
    case nil: return String(localized: "i18n:Common.OK", bundle: #bundle)
    }
  }

  private var alertIsPresented: Binding<Bool> {
    Binding(
      get: { alertKind != nil },
      set: { if !$0 { alertKind = nil } }
    )
  }

  private func commitAlert() {
    let name = alertText.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    switch alertKind {
    case .newPlaylist:
      library.addPlaylist(name: name)
    case .newDynamicPlaylist:
      library.addDynamicPlaylist(name: name)
    case let .rename(id):
      library.renamePlaylist(id: id, newName: name)
    case nil:
      break
    }
  }
}
