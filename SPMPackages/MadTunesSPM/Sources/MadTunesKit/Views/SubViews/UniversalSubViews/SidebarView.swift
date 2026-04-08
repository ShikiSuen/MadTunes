// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import MadTunesTips
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
          HStack {
            Label(playlist.name, systemImage: playlistIcon(for: playlist))
            // Phase 158: Show warning icon for failed folder playlists.
            if playlist.kind == .folderList,
               library.sandboxHealthReport?.failedFolderPlaylistIDs.contains(playlist.id) == true {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.caption2)
            }
          }
          .tag(playlist.id)
          .contextMenu {
            Section {
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
                renameAlertText = playlist.name
                renamePlaylistID = playlist.id
              } label: {
                Label(String(localized: "i18n:Common.Rename", bundle: #bundle), systemImage: "pencil")
              }
              if playlist.kind != .folderList {
                Button {
                  library.duplicatePlaylist(id: playlist.id)
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.DuplicatePlaylist", bundle: #bundle),
                    systemImage: "doc.on.doc"
                  )
                }
              }
            } header: {
              Text(playlist.kind.localizedDescription)
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
        getMenu4CreatingPlaylist()
          .buttonBorderShape(.capsule)
          .menuIndicator(.hidden)
          .buttonStyle(.bordered)
          .tint(.primary)
          .background {
            Color.clear
              .popoverTip(
                mainVM.tutorialTips.currentTip as? Tip4NonStaticPlaylists,
                arrowEdge: .top
              )
              .environment(\.colorScheme, mainVM.systemColorScheme ?? colorScheme)
              .id(mainVM.systemColorScheme ?? colorScheme)
          }
      } header: {
        Text("i18n:Sidebar.Sections.Playlists", bundle: #bundle)
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("MadTunes")
    // Phase 160: Rename-only alert (create alerts moved to Scene level via MainVM).
    .alert(
      String(localized: "i18n:Sidebar.Alert.RenamePlaylistTitle", bundle: #bundle),
      isPresented: Binding(
        get: { renamePlaylistID != nil },
        set: { if !$0 { renamePlaylistID = nil } }
      )
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.NewNamePlaceholder", bundle: #bundle),
        text: $renameAlertText
      )
      Button(String(localized: "i18n:Common.Rename", bundle: #bundle)) {
        commitRename()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
  }

  // MARK: Private

  @Environment(\.colorScheme) private var colorScheme
  @Environment(MadTunesViewModel.self) private var mainVM
  @Binding private var selectedPlaylistID: UUID?
  /// Phase 160: Local rename alert state (create state is shared via MainVM).
  @State private var renamePlaylistID: UUID?
  @State private var renameAlertText = ""

  private var library: MusicLibrary

  /// Phase 117: All user-created playlists (dynamic + static), preserving library order.
  private var userPlaylists: [Playlist] {
    Array(library.playlists.dropFirst(2))
  }

  @ViewBuilder
  private func getMenu4CreatingPlaylist(implicitTextControl: Bool = true) -> some View {
    let showDropdownButtonTitleText = !implicitTextControl || userPlaylists.isEmpty
    Menu {
      Button {
        mainVM.playlistCreationAlertText = ""
        mainVM.playlistCreationAlertKind = .dynamicPlaylist
      } label: {
        Label(
          String(localized: "i18n:Sidebar.NewDynamicPlaylist", bundle: #bundle),
          systemImage: "gearshape.2"
        )
      }

      Button {
        mainVM.playlistCreationAlertText = ""
        mainVM.playlistCreationAlertKind = .staticPlaylist
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
      Group {
        if showDropdownButtonTitleText {
          Label {
            Text("i18n:Sidebar.NewPlaylist", bundle: #bundle)
              .font(.caption)
          } icon: {
            Image(systemName: "plus")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Image(systemName: "plus")
            .help(Text("i18n:Sidebar.NewPlaylist", bundle: #bundle))
        }
      }
    }
    .fixedSize(horizontal: !showDropdownButtonTitleText, vertical: false)
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

  /// Phase 160: Commit the rename-only alert.
  private func commitRename() {
    guard let id = renamePlaylistID else { return }
    let name = renameAlertText.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    library.renamePlaylist(id: id, newName: name)
    renamePlaylistID = nil
    renameAlertText = ""
  }
}
