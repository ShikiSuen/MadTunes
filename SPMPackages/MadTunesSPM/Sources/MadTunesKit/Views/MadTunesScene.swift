// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - MadTunesScene

/// The top-level Scene provided by MadTunesKit.
/// Use this from the `@main` App struct:
///
///     @main struct MadTunesApp: App {
///       var body: some Scene { MadTunesScene() }
///     }
public struct MadTunesScene: Scene {
  // MARK: Lifecycle

  public init() {
    // Phase 71: Disable tab bar for single-window app on AppKit targets.
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    NSWindow.allowsAutomaticWindowTabbing = false
    #endif
  }

  // MARK: Public

  public var body: some Scene {
    WindowGroup {
      MadTunesMainView()
        .frame(
          minWidth: OS.type == .macOS ? 852 * vm.uiFactor : 720,
          minHeight: OS.type == .macOS ? 574 * vm.uiFactor : 720
        )
        // Phase 69: Handle files opened via "Open In" / Share sheet / Finder.
        .onOpenURL { url in
          vm.importURLs([url])
        }
    }
    .commands {
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
          Button {
            vm.isFileImporterPresented = true
          } label: {
            Label(
              String(localized: "i18n:Import.ImportFiles", bundle: #bundle),
              systemImage: "music.note"
            )
          }
          .keyboardShortcut("o", modifiers: [.command, .shift, .option])
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
        #if DEBUG
        Divider()
        Menu {
          if !vm.library.isImporting, !vm.library.albums.isEmpty {
            Button(role: .destructive) {
              vm.player.stop()
              vm.library.clearDatabase()
            } label: {
              Label(
                String(localized: "i18n:Debug.ClearDatabase", bundle: #bundle),
                systemImage: "trash"
              )
            }
          }
        } label: {
          Label("# DEBUG".description, systemImage: "pc")
        }
        #endif
      }
      GlobalControlMenuCommands()
      CommandGroup(before: .toolbar) {
        if !vm.library.isImporting, !vm.useTableView {
          Menu {
            Picker(
              String(localized: "i18n:AlbumSortMethod.Label", bundle: #bundle),
              selection: $vm.gridVM.albumSortOrder
            ) {
              ForEach(AlbumSortOrder.allCases, id: \.self) { order in
                Text(order.localizedName).tag(order)
              }
            }
            .pickerStyle(.inline)
          } label: {
            Label(String(localized: "i18n:AlbumSortMethod.Label", bundle: #bundle), systemImage: "arrow.up.arrow.down")
              .tint(.primary)
          }
          Divider()
        }
      }
    }
    .windowResizability(.contentSize)
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared
}
