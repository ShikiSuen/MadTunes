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
    coreScene
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
          #if DEBUG
          Divider()
          Menu {
            if !vm.library.isImporting {
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
              Label(
                String(localized: "i18n:AlbumSortMethod.Label", bundle: #bundle),
                systemImage: "arrow.up.arrow.down"
              )
              .tint(.primary)
            }
            Divider()
          }
        }
      }
      .windowResizability(.contentSize)
  }

  // MARK: Internal

  @SceneBuilder var coreScene: some Scene {
    #if !os(macOS)
    WindowGroup {
      coreSceneView
    }
    #else
    Window("MadTunes", id: "main") {
      coreSceneView
    }
    #endif
  }

  @ViewBuilder var coreSceneView: some View {
    @Bindable var bindableVM = vm
    let isWPUI = WPPhoneViewModel.shouldUseWPUI(screenVM: vm.screenVM)
    let windowMinSize = getWindowMinSize(isWPUI: isWPUI)
    Group {
      // Phase 75: Use WP Metro-style UI for iPhone / compact layout.
      if isWPUI {
        WPMainView()
          // Phase 121: Predicate editor sheet at stable Scene level —
          // survives iPad WPUI↔desktop switch, preserving editing state.
          .sheet(item: $bindableVM.predicateEditorPlaylist) { _ in
            if let editorVM = vm.predicateEditorVM {
              WPPredicateEditorView(vm: editorVM)
                .id(colorScheme)
                .interactiveDismissDisabled(true)
                .environment(vm.phoneVM)
            }
          }
          .fontWidth(.condensed)
      } else {
        MadTunesMainView()
          // Phase 121: Predicate editor sheet at stable Scene level —
          // survives iPad WPUI↔desktop switch, preserving editing state.
          .sheet(item: $bindableVM.predicateEditorPlaylist) { _ in
            if let editorVM = vm.predicateEditorVM {
              PredicateEditorView(vm: editorVM)
                .id(colorScheme)
                .interactiveDismissDisabled(true)
            }
          }
          .fontWidth(.condensed)
      }
    }
    .frame(
      minWidth: windowMinSize.width,
      minHeight: windowMinSize.height
    )
    // Phase 69: Handle files opened via "Open In" / Share sheet / Finder.
    // Phase 100: On native macOS, MadTunesNSAppDelegate.application(_:open:)
    // handles file-open events as a single batch. Skip .onOpenURL on macOS to
    // avoid duplicate imports (delegate + onOpenURL both firing).
    #if !os(macOS)
    .onOpenURL { url in
      vm.importURLs([url])
    }
    #endif
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared
  @Environment(\.colorScheme) private var colorScheme

  private func getWindowMinSize(isWPUI: Bool) -> CGSize {
    guard !isWPUI else { return CGSize(width: 320, height: 568) }
    return CGSize(
      width: OS.type == .macOS ? 852 * vm.uiFactor : 320,
      height: OS.type == .macOS ? 574 * vm.uiFactor : 568
    )
  }
}
