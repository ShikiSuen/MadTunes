// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import TipKit
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
    if resetTipsOnNextStartup {
      resetTipsOnNextStartup.toggle()
      do {
        try Tips.resetDatastore()
      } catch {
        print("[TIPS] \(error)")
      }
    }
    do {
      try Tips.configure([
        .displayFrequency(.immediate),
        .datastoreLocation(.applicationDefault),
      ])
    } catch {
      print("[TIPS] \(error)")
    }
  }

  // MARK: Public

  public var body: some Scene {
    coreScene
      .commands {
        MainFileMenuCommands()
        MainControlMenuCommands()
        MainViewMenuCommands()
        MainHelpMenuCommands()
      }
      .windowResizability(.contentSize)
  }

  // MARK: Internal

  @SceneBuilder var coreScene: some Scene {
    #if !os(macOS)
    WindowGroup {
      MainSceneView()
    }
    #else
    Window("MadTunes", id: "main") {
      MainSceneView()
    }
    #endif
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared

  @AppStorage(wrappedValue: false, "MadTunes.resetTipsOnNextStartup") private var resetTipsOnNextStartup: Bool
}

// MARK: - MainSceneView

/// Phase 161: Extracted from MadTunesScene.coreSceneView.
struct MainSceneView: View {
  // MARK: Internal

  var body: some View {
    @Bindable var bindableVM = vm
    let isWPUI = WPPhoneViewModel.shouldUseWPUI(screenVM: vm.screenVM)
    let windowMinSize = getWindowMinSize(isWPUI: isWPUI)
    let importerColorScheme: ColorScheme = isWPUI ? .dark : colorScheme
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
        DesktopMainView()
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
    .background {
      ZStack {
        // Phase 160: Shared create-playlist alert at Scene level —
        // survives iPad WPUI↔desktop switch, shared by SidebarView, WPUI, and MainMenu.
        Color.clear
          .alert(
            playlistCreationAlertTitle,
            isPresented: Binding(
              get: { vm.playlistCreationAlertKind != nil },
              set: { if !$0 { vm.playlistCreationAlertKind = nil } }
            )
          ) {
            TextField(
              String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
              text: $bindableVM.playlistCreationAlertText
            )
            Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
              vm.commitPlaylistCreation()
            }
            Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
          }
        // Phase 137-1: FileImporter 不能鏈式掛在同一個 view，否則其中一個
        // 可能無法呼叫；改用兩個 Color.clear 宿主分開掛載。
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Phase 137-1: Keep global import presenter at Scene level so WPUI and
        // desktop layouts share the same importer host.
        Color.clear
          .fileImporter(
            isPresented: $bindableVM.isFolderImporterPresented,
            allowedContentTypes: SupportedFormats.macImportTypes,
            allowsMultipleSelection: true
          ) { result in
            if case let .success(urls) = result {
              vm.importURLs(urls)
            }
          }
        #else
        Color.clear
          .fileImporter(
            isPresented: $bindableVM.isFileImporterPresented,
            allowedContentTypes: SupportedFormats.fileImportTypes,
            allowsMultipleSelection: true
          ) { result in
            if case let .success(urls) = result {
              vm.importURLs(urls)
            }
          }
        Color.clear
          .fileImporter(
            isPresented: $bindableVM.isFolderImporterPresented,
            allowedContentTypes: SupportedFormats.folderImportTypes,
            allowsMultipleSelection: true
          ) { result in
            if case let .success(urls) = result {
              vm.importURLs(urls)
            }
          }
        #endif
        // Phase 137-2: Unify the hook of fileImporter for folder playlist path URL.
        Color.clear
          .fileImporter(
            isPresented: $bindableVM.isImporterForFolderPlaylistPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
          ) { result in
            switch result {
            case let .success(urls):
              guard let folderURL = urls.first else { return }
              // addFolderPlaylist manages security-scoped access internally.
              let playlistName = folderURL.deletingPathExtension().lastPathComponent
              Task {
                await vm.library.addFolderPlaylist(name: playlistName, folderURL: folderURL)
              }
            case .failure:
              break
            }
          }
        // Phase 164: Reapprove Sandbox Privileges — confirmation dialog.
        Color.clear
          .confirmationDialog(
            String(localized: "i18n:Import.ReapproveSandboxPrivileges", bundle: #bundle),
            isPresented: $bindableVM.isReapproveSandboxDialogPresented,
            titleVisibility: .visible
          ) {
            Button(String(localized: "i18n:Common.Proceed", bundle: #bundle)) {
              vm.isReapproveSandboxImporterPresented = true
            }
            Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
          } message: {
            Text("i18n:Import.ReapproveSandboxPrivileges.Explanation", bundle: #bundle)
          }
        // Phase 164: Reapprove Sandbox Privileges — folder picker.
        Color.clear
          .fileImporter(
            isPresented: $bindableVM.isReapproveSandboxImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
          ) { result in
            if case let .success(urls) = result, let folderURL = urls.first {
              vm.sandboxReapprovalReport = vm.library.reapproveSandboxPrivileges(folderURL: folderURL)
            }
          }
        // Phase 171: Reset Tutorial Tips — scheduled confirmation alert.
        Color.clear
          .alert(
            String(localized: "i18n:MainMenu.Help.resetTutorialTips", bundle: #bundle),
            isPresented: Binding(
              get: { vm.showResetTipsScheduledAlert },
              set: { if !$0 { vm.showResetTipsScheduledAlert = false } }
            )
          ) {
            Button(String(localized: "i18n:Common.Done", bundle: #bundle)) {
              vm.showResetTipsScheduledAlert = false
            }
          } message: {
            Text("i18n:MainMenu.Help.resetTutorialTips.Confirmation", bundle: #bundle)
          }
        // Phase 164: Reapprove Sandbox Privileges — result report alert.
        Color.clear
          .alert(
            String(localized: "i18n:Import.ReapproveSandboxPrivileges", bundle: #bundle),
            isPresented: Binding(
              get: { vm.sandboxReapprovalReport != nil },
              set: { if !$0 { vm.sandboxReapprovalReport = nil } }
            )
          ) {
            Button(String(localized: "i18n:Common.Done", bundle: #bundle)) {
              vm.sandboxReapprovalReport = nil
            }
          } message: {
            if let report = vm.sandboxReapprovalReport {
              Text(
                "i18n:Import.ReapproveSandboxPrivileges.Report \(report.totalChecked) \(report.totalRefreshed)",
                bundle: #bundle
              )
            }
          }
      }
      .environment(\.colorScheme, importerColorScheme)
    }
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

  /// Phase 160: Alert title for the shared create-playlist alert.
  private var playlistCreationAlertTitle: String {
    switch vm.playlistCreationAlertKind {
    case .staticPlaylist:
      return String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle)
    case .dynamicPlaylist:
      return String(localized: "i18n:Sidebar.Alert.NewDynamicPlaylistTitle", bundle: #bundle)
    case nil:
      return ""
    }
  }

  private func getWindowMinSize(isWPUI: Bool) -> CGSize {
    guard !isWPUI else { return CGSize(width: 320, height: 568) }
    return CGSize(
      width: OS.type == .macOS ? 852 * vm.uiFactor : 320,
      height: OS.type == .macOS ? 574 * vm.uiFactor : 568
    )
  }
}
