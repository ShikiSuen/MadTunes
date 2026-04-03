// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - GlobalControlMenuCommands

/// Phase 63: All keyboard shortcuts surfaced via CommandMenu so that
/// tools like KeyClu / CheatSheet can discover them from MainMenu.
struct MainControlMenuCommands: Commands {
  // MARK: Internal

  @CommandsBuilder @MainActor var body: some Commands {
    CommandMenu(
      String(
        localized: "i18n:Menu.Controls",
        defaultValue: "Controls",
        bundle: #bundle
      )
    ) {
      Group {
        switch vm.desktopContentLayout {
        case .asTableView:
          commandsOfControlForAlbumTableView
        case .asAlbumHGrid, .asAlbumVGrid:
          commandsOfControlForAlbumGridView
        }
      }
      // Phase 121: Block all hotkeys while predicate editor is presented.
      .disabled(vm.predicateEditorPlaylist != nil)

      // Phase 127: Audio output device routing (macOS only).
      #if os(macOS)
      Section {
        audioOutputDeviceMenu
      }
      #endif
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
            Task {
              await vm.player.setQueue(selected, startingAt: 0)
            }
          } else {
            withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
              vm.gridVM.expandedAlbumID = nil
            }
          }
        } else if vm.gridVM.highlightedAlbumIDs.count == 1 {
          withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
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
        withAnimation(.interactiveSpring.nerf(vm.gridVM.legacyHardwareMode)) {
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
    // Phase 91: Play like double-click — Cmd+↓ / Enter / Shift+Space
    // Queue ALL displayed tracks starting from cursor/selected position.
    Section {
      Button {
        vm.tableVM.playSelectedAsDoubleClick()
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

      // Phase 91: Enter — play like double-click.
      Button {
        vm.tableVM.playSelectedAsDoubleClick()
      } label: {
        Label(
          String(
            localized: "i18n:Menu.PlayFromSelected",
            defaultValue: "Play from Selected",
            bundle: #bundle
          ),
          systemImage: "play.fill"
        )
      }
      .keyboardShortcut(.return, modifiers: [])
      .disabled(vm.selectedTrackIDs.isEmpty)

      // Phase 91: Shift+Space — play like double-click.
      Button {
        vm.tableVM.playSelectedAsDoubleClick()
      } label: {
        Label(
          String(
            localized: "i18n:Menu.PlayFromSelected",
            defaultValue: "Play from Selected",
            bundle: #bundle
          ),
          systemImage: "play.fill"
        )
      }
      .keyboardShortcut(.space, modifiers: [.shift])
      .disabled(vm.selectedTrackIDs.isEmpty)

      // Phase 91: Space alone — toggle play/pause.
      Button {
        Task {
          await vm.player.togglePlayPause()
        }
      } label: {
        Label(
          String(
            localized: "i18n:Menu.TogglePlayPause",
            defaultValue: "Toggle Play/Pause",
            bundle: #bundle
          ),
          systemImage: "playpause.fill"
        )
      }
      .keyboardShortcut(.space, modifiers: [])
    }

    // UIKit: Arrow keys move selection in List.
    #if !canImport(AppKit) || targetEnvironment(macCatalyst)
    Section {
      Button {
        vm.tableVM.moveSelection(
          direction: -1,
          extend: false,
          tracks: vm.tableVM.currentTracksDisplayed,
          mainVM: vm
        )
      } label: {
        Label(
          String(
            localized: "i18n:Menu.SelectPreviousTrack",
            defaultValue: "Select previous track",
            bundle: #bundle
          ),
          systemImage: "arrow.up"
        )
      }
      .keyboardShortcut(.upArrow, modifiers: [])
      .disabled(vm.tableVM.currentTracksDisplayed.isEmpty)

      Button {
        vm.tableVM.moveSelection(
          direction: 1,
          extend: false,
          tracks: vm.tableVM.currentTracksDisplayed,
          mainVM: vm
        )
      } label: {
        Label(
          String(
            localized: "i18n:Menu.SelectNextTrack",
            defaultValue: "Select next track",
            bundle: #bundle
          ),
          systemImage: "arrow.down"
        )
      }
      .keyboardShortcut(.downArrow, modifiers: [])
      .disabled(vm.tableVM.currentTracksDisplayed.isEmpty)

      Button {
        vm.tableVM.moveSelection(
          direction: -1,
          extend: true,
          tracks: vm.tableVM.currentTracksDisplayed,
          mainVM: vm
        )
      } label: {
        Label(
          String(
            localized: "i18n:Menu.ExtendSelectionUp",
            defaultValue: "Extend selection up",
            bundle: #bundle
          ),
          systemImage: "arrow.up"
        )
      }
      .keyboardShortcut(.upArrow, modifiers: [.shift])
      .disabled(vm.tableVM.currentTracksDisplayed.isEmpty)

      Button {
        vm.tableVM.moveSelection(
          direction: 1,
          extend: true,
          tracks: vm.tableVM.currentTracksDisplayed,
          mainVM: vm
        )
      } label: {
        Label(
          String(
            localized: "i18n:Menu.ExtendSelectionDown",
            defaultValue: "Extend selection down",
            bundle: #bundle
          ),
          systemImage: "arrow.down"
        )
      }
      .keyboardShortcut(.downArrow, modifiers: [.shift])
      .disabled(vm.tableVM.currentTracksDisplayed.isEmpty)
    }
    #endif

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
    // Phase 74: PgUp/PgDn/Home/End for UIKit targets.
    // Menu commands bypass UICollectionView's key command interception on macCatalyst.
    #if !canImport(AppKit) || targetEnvironment(macCatalyst)
    Section {
      Button { vm.tableVM.navigateToPage(.pageUp, isShift: false) } label: {
        Text(String(localized: "i18n:Menu.PageUp", defaultValue: "Page Up", bundle: #bundle))
      }
      .keyboardShortcut(.pageUp, modifiers: [])
      Button { vm.tableVM.navigateToPage(.pageDown, isShift: false) } label: {
        Text(String(localized: "i18n:Menu.PageDown", defaultValue: "Page Down", bundle: #bundle))
      }
      .keyboardShortcut(.pageDown, modifiers: [])
      Button { vm.tableVM.navigateToPage(.home, isShift: false) } label: {
        Text(String(localized: "i18n:Menu.Home", defaultValue: "Home", bundle: #bundle))
      }
      .keyboardShortcut(.home, modifiers: [])
      Button { vm.tableVM.navigateToPage(.end, isShift: false) } label: {
        Text(String(localized: "i18n:Menu.End", defaultValue: "End", bundle: #bundle))
      }
      .keyboardShortcut(.end, modifiers: [])
      Button { vm.tableVM.navigateToPage(.pageUp, isShift: true) } label: {
        Text(String(
          localized: "i18n:Menu.ExtendSelectionPageUp",
          defaultValue: "Extend Selection Page Up",
          bundle: #bundle
        ))
      }
      .keyboardShortcut(.pageUp, modifiers: [.shift])
      Button { vm.tableVM.navigateToPage(.pageDown, isShift: true) } label: {
        Text(String(
          localized: "i18n:Menu.ExtendSelectionPageDown",
          defaultValue: "Extend Selection Page Down",
          bundle: #bundle
        ))
      }
      .keyboardShortcut(.pageDown, modifiers: [.shift])
      Button { vm.tableVM.navigateToPage(.home, isShift: true) } label: {
        Text(String(
          localized: "i18n:Menu.ExtendSelectionToStart",
          defaultValue: "Extend Selection to Start",
          bundle: #bundle
        ))
      }
      .keyboardShortcut(.home, modifiers: [.shift])
      Button { vm.tableVM.navigateToPage(.end, isShift: true) } label: {
        Text(String(
          localized: "i18n:Menu.ExtendSelectionToEnd",
          defaultValue: "Extend Selection to End",
          bundle: #bundle
        ))
      }
      .keyboardShortcut(.end, modifiers: [.shift])
    }
    .disabled(vm.tableVM.currentTracksDisplayed.isEmpty)
    #endif
  }

  // Phase 127: Audio output device submenu (macOS only).
  #if os(macOS)
  @ViewBuilder private var audioOutputDeviceMenu: some View {
    let manager = vm.player.outputDeviceManager
    let currentUID = manager.selectedDeviceUID
    let defaultUID = manager.cachedSystemDefaultDeviceUID

    Menu {
      Button {
        vm.player.setOutputDevice(uid: nil)
      } label: {
        HStack {
          Text(
            String(
              localized: "i18n:AudioOutput.SystemDefault",
              defaultValue: "System Default",
              bundle: #bundle
            )
          )
          if currentUID == nil {
            Spacer()
            Image(systemName: "checkmark")
          }
        }
      }

      Divider()

      ForEach(manager.outputDevices) { device in
        Button {
          vm.player.setOutputDevice(uid: device.uid)
        } label: {
          HStack {
            Text(verbatim: device.name)
            if device.uid == defaultUID {
              Text(verbatim: "⌂").foregroundStyle(.secondary)
            }
            if device.uid == currentUID {
              Spacer()
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      Label(
        String(
          localized: "i18n:AudioOutput.Label",
          defaultValue: "Audio Output",
          bundle: #bundle
        ),
        systemImage: "speaker.wave.2.circle"
      )
    }
  }
  #endif
}
