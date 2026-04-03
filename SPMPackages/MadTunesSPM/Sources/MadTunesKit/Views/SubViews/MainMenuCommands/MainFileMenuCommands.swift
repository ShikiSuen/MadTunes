// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - MainFileMenuCommands

/// Phase 161: Extracted from MadTunesScene — File menu commands
/// (import files/folders, new playlist, debug).
struct MainFileMenuCommands: Commands {
  // MARK: Internal

  @CommandsBuilder @MainActor var body: some Commands {
    CommandGroup(replacing: .newItem) {
      switch OS.isAppKit {
      case true:
        Button {
          vm.isFolderImporterPresented = true
        } label: {
          Label(
            String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle),
            systemImage: "folder"
          )
        }
        .keyboardShortcut("o")
      case false:
        // 此處不設定熱鍵。熱鍵全權交給 `MadTunesAppDelegate` 處理。
        // 另外，此處也不需要系統判斷，不然 iPadOS 會出現兩個「開啟單個檔案」的命令。
        // 總之，這裡只需要這個 CMD+Shift+O 的命令就行。
        Button {
          vm.isFolderImporterPresented = true
        } label: {
          Label(
            String(localized: "i18n:Import.ImportFolder", bundle: #bundle),
            systemImage: "folder"
          )
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])
      }
      // Phase 160: New Playlist submenu in File menu.
      Divider()
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
        Label(
          String(localized: "i18n:Sidebar.NewPlaylist", bundle: #bundle),
          systemImage: "plus"
        )
      }
      #if DEBUG
      Divider()
      Menu {
        if !vm.library.isImporting {
          debugButtonDeletingEntireDB
        }
      } label: {
        Label("# DEBUG".description, systemImage: "pc")
      }
      #endif
    }
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared

  @ViewBuilder private var debugButtonDeletingEntireDB: some View {
    Button(role: .destructive) {
      Task { await vm.player.stop() }
      vm.library.clearDatabase()
    } label: {
      Label(
        String(localized: "i18n:Debug.ClearDatabase", bundle: #bundle),
        systemImage: "trash"
      )
    }
  }
}
