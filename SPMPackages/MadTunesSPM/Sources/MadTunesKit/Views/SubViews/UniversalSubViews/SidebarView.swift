// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - SidebarView

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

      Section {
        // Phase 117: All user playlists (dynamic + static + folder) in one list with drag-reorder.
        ForEach(userPlaylists) { playlist in
          Label(playlist.name, systemImage: playlistIcon(for: playlist))
            .tag(playlist.id)
            .contextMenu {
              if playlist.kind == .dynamicList {
                Button {
                  mainVM.openPredicateEditor(for: playlist)
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.EditPredicates", bundle: #bundle),
                    systemImage: "slider.horizontal.3"
                  )
                }
                // Phase 135: Data source submenu for dynamic playlists.
                DataSourceMenu(playlist: playlist, library: library)
              }
              if playlist.kind == .folderList {
                Button {
                  Task {
                    await library.rescanFolderPlaylist(id: playlist.id)
                  }
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.RescanFolder", bundle: #bundle),
                    systemImage: "arrow.clockwise"
                  )
                }

                #if os(macOS) && !targetEnvironment(macCatalyst)
                Divider()
                Button {
                  openFolderInFinder(for: playlist.id)
                } label: {
                  Label(
                    String(localized: "i18n:ContextMenu.ShowInFinder", bundle: #bundle),
                    systemImage: "folder"
                  )
                }
                .disabled(library.folderURL(forFolderPlaylistID: playlist.id) == nil)
                #endif
              }
              Button {
                alertText = playlist.name
                alertKind = .rename(playlist.id)
              } label: {
                Label(String(localized: "i18n:Common.Rename", bundle: #bundle), systemImage: "pencil")
              }
              if playlist.kind != .folderList {
                Button {
                  library.duplicatePlaylist(id: playlist.id)
                } label: {
                  Label(String(localized: "i18n:Sidebar.DuplicatePlaylist", bundle: #bundle), systemImage: "doc.on.doc")
                }
              }
              Divider()
              Button(role: .destructive) {
                if selectedPlaylistID == playlist.id {
                  selectedPlaylistID = library.playlists.first?.id
                }
                if playlist.kind == .folderList {
                  library.removeFolderPlaylist(id: playlist.id)
                } else {
                  library.removePlaylist(id: playlist.id)
                }
              } label: {
                Label(String(localized: "i18n:Common.Delete", bundle: #bundle), systemImage: "trash")
              }
            }
        }
        .onDelete { indexSet in
          let playlists = userPlaylists
          for index in indexSet {
            let playlist = playlists[index]
            if selectedPlaylistID == playlist.id {
              selectedPlaylistID = library.playlists.first?.id
            }
            if playlist.kind == .folderList {
              library.removeFolderPlaylist(id: playlist.id)
            } else {
              library.removePlaylist(id: playlist.id)
            }
          }
        }
        .onMove { source, destination in
          library.moveUserPlaylists(fromOffsets: source, toOffset: destination)
        }
        newPlaylistMenu
      } header: {
        Text("i18n:Sidebar.Sections.Playlists", bundle: #bundle)
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

  @Environment(MadTunesViewModel.self) private var mainVM
  @Binding private var selectedPlaylistID: UUID?
  // Alert state — shared across both "New Playlist" and "Rename"
  @State private var alertKind: AlertKind?
  @State private var alertText = ""

  private var library: MusicLibrary

  /// Phase 117: All user-created playlists (dynamic + static), preserving library order.
  private var userPlaylists: [Playlist] {
    Array(library.playlists.dropFirst(2))
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

  @ViewBuilder private var newPlaylistMenu: some View {
    Menu {
      Button {
        alertText = ""
        alertKind = .newDynamicPlaylist
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewDynamicPlaylist", bundle: #bundle),
          systemImage: "gearshape.2"
        )
      }

      Button {
        alertText = ""
        alertKind = .newPlaylist
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewStaticPlaylist", bundle: #bundle),
          systemImage: "music.note.list"
        )
      }

      Divider()

      Button {
        mainVM.isImporterForFolderPlaylistPresented = true
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewFolderPlaylist", bundle: #bundle),
          systemImage: "folder.fill"
        )
      }
    } label: {
      Label(
        String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle),
        systemImage: "plus"
      )
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonBorderShape(.capsule)
    .menuIndicator(.hidden)
    .buttonStyle(.bordered)
    .tint(.primary)
  }

  /// Phase 135: Delegate to Playlist.icon4SFSymbols().
  private func playlistIcon(for playlist: Playlist) -> String {
    playlist.icon4SFSymbols()
  }

  #if os(macOS) && !targetEnvironment(macCatalyst)
  private func openFolderInFinder(for playlistID: UUID) {
    guard let folderURL = library.folderURL(forFolderPlaylistID: playlistID) else { return }
    NSWorkspace.shared.open(folderURL)
  }
  #endif

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
