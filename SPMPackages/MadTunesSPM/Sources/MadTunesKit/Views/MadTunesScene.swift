// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
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

  public init() {}

  // MARK: Public

  public var body: some Scene {
    WindowGroup {
      MadTunesMainView()
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        switch OS.isAppKit {
        case true:
          Button {
            viewModel.isFolderImporterPresented = true
          } label: {
            Label(
              String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle),
              systemImage: "folder"
            )
          }
          .keyboardShortcut("o")
        case false:
          Button {
            viewModel.isFileImporterPresented = true
          } label: {
            Label(
              String(localized: "i18n:Import.ImportFiles", bundle: #bundle),
              systemImage: "music.note"
            )
          }
          .keyboardShortcut("o")
          Button {
            viewModel.isFolderImporterPresented = true
          } label: {
            Label(
              String(localized: "i18n:Import.ImportFolder", bundle: #bundle),
              systemImage: "folder"
            )
          }
          .keyboardShortcut("o", modifiers: [.command, .shift])
        }
      }
    }
  }

  // MARK: Private

  @State private var viewModel = MadTunesViewModel.shared
}
