// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - GlobalControlMenuCommands

/// Phase 63: All keyboard shortcuts surfaced via CommandMenu so that
/// tools like KeyClu / CheatSheet can discover them from MainMenu.
struct GlobalControlMenuCommands: Commands {
  // MARK: Internal

  @CommandsBuilder @MainActor var body: some Commands {
    CommandMenu(
      String(
        localized: "i18n:Menu.Controls",
        defaultValue: "Controls",
        bundle: #bundle
      )
    ) {
      if vm.useTableView {
        commandsOfControlForAlbumTableView
      } else {
        commandsOfControlForAlbumGridView
      }
    }
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared

  // MARK: - Grid Mode Commands

  @ViewBuilder private var commandsOfControlForAlbumGridView: some View {
    // Phase 63: Play / Expand — Cmd+↓
    Section {
      Button {
        let albums = vm.gridVM.currentAlbumsDisplayed
        if let expandedID = vm.gridVM.expandedAlbumID,
           let album = albums.first(where: { $0.id == expandedID }) {
          let selected = album.tracks.filter { vm.selectedTrackIDs.contains($0.id) }
          if !selected.isEmpty {
            vm.player.setQueue(selected, startingAt: 0)
          } else {
            withAnimation(.easeInOut(duration: 0.3)) {
              vm.gridVM.expandedAlbumID = nil
            }
          }
        } else if vm.gridVM.highlightedAlbumIDs.count == 1 {
          withAnimation(.easeInOut(duration: 0.3)) {
            vm.gridVM.expandedAlbumID = vm.gridVM.highlightedAlbumIDs.first
          }
        }
      } label: {
        Label(
          String(
            localized: "i18n:Menu.PlayOrExpand",
            defaultValue: "Play / Expand",
            bundle: #bundle
          ),
          systemImage: "play.fill"
        )
      }
      .keyboardShortcut(.downArrow, modifiers: [.command])

      // Collapse — Cmd+↑
      Button {
        withAnimation(.easeInOut(duration: 0.3)) {
          vm.gridVM.expandedAlbumID = nil
        }
      } label: {
        Label(
          String(
            localized: "i18n:Menu.CollapseAlbum",
            defaultValue: "Collapse Album",
            bundle: #bundle
          ),
          systemImage: "rectangle.compress.vertical"
        )
      }
      .keyboardShortcut(.upArrow, modifiers: [.command])
      .disabled(vm.gridVM.expandedAlbumID == nil)
    }
  }

  // MARK: - Table Mode Commands

  @ViewBuilder private var commandsOfControlForAlbumTableView: some View {
    // Phase 63: Play selected — Cmd+↓
    Section {
      Button {
        let tracks = vm.tableVM.currentTracksDisplayed
        let selected = tracks.filter { vm.selectedTrackIDs.contains($0.id) }
        if !selected.isEmpty {
          vm.player.setQueue(selected, startingAt: 0)
        }
      } label: {
        Label(
          String(
            localized: "i18n:Menu.PlaySelected",
            defaultValue: "Play Selected",
            bundle: #bundle
          ),
          systemImage: "play.fill"
        )
      }
      .keyboardShortcut(.downArrow, modifiers: [.command])
      .disabled(vm.selectedTrackIDs.isEmpty)
    }
    // Phase 52: Menu commands for playlist track reordering.
    Section {
      Button {
        vm.tableVM.moveSelectedTracksUp()
      } label: {
        Label(
          String(
            localized: "i18n:Menu.MoveTrackUp",
            defaultValue: "Move Track Up",
            bundle: #bundle
          ),
          systemImage: "arrow.up"
        )
      }
      .keyboardShortcut(.upArrow, modifiers: [.option])
      .disabled(!vm.tableVM.canMoveSelectedTracksUp)
      Button {
        vm.tableVM.moveSelectedTracksDown()
      } label: {
        Label(
          String(
            localized: "i18n:Menu.MoveTrackDown",
            defaultValue: "Move Track Down",
            bundle: #bundle
          ),
          systemImage: "arrow.down"
        )
      }
      .keyboardShortcut(.downArrow, modifiers: [.option])
      .disabled(!vm.tableVM.canMoveSelectedTracksDown)
    }
  }
}
