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

  @State private var viewModel = MadTunesViewModel.shared
}

// MARK: - MadTunesMainView

struct MadTunesMainView: View {
  // MARK: Internal

  var body: some View {
    @Bindable var vm = viewModel
    NavigationSplitView(
      columnVisibility: $vm.screenVM.splitViewVisibility,
      preferredCompactColumn: $viewColumn
    ) {
      SidebarView(library: viewModel.library, selectedPlaylistID: $vm.selectedPlaylistID)
        .navigationSplitViewColumnWidth(min: 210, ideal: 210, max: 210)
        .trackCanvasSize(debounceDelay: 0.3) {
          let existingWidth = vm.screenVM.actualSidebarWidthObserved
          let newValue = $0.width.rounded(.up)
          guard existingWidth != newValue else { return }
          vm.screenVM.actualSidebarWidthObserved = newValue
        }
    } detail: {
      let albums = viewModel.currentAlbums
      contentArea(albums: albums)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          ZStack {
            switch OS.isAppKit {
            case true:
              Color.clear
                .fileImporter(
                  isPresented: $vm.isFolderImporterPresented,
                  allowedContentTypes: SupportedFormats.macImportTypes,
                  allowsMultipleSelection: true
                ) { result in
                  if case let .success(urls) = result {
                    viewModel.importURLs(urls)
                  }
                }
            case false:
              Color.clear
                .fileImporter(
                  isPresented: $vm.isFileImporterPresented,
                  allowedContentTypes: SupportedFormats.fileImportTypes,
                  allowsMultipleSelection: true
                ) { result in
                  if case let .success(urls) = result {
                    viewModel.importURLs(urls)
                  }
                }
              Color.clear
                .fileImporter(
                  isPresented: $vm.isFolderImporterPresented,
                  allowedContentTypes: SupportedFormats.folderImportTypes,
                  allowsMultipleSelection: true
                ) { result in
                  if case let .success(urls) = result {
                    viewModel.importURLs(urls)
                  }
                }
            }
          }
        }
        .safeAreaInset(edge: .bottom) {
          ZStack {
            BottomBarBackground()
            PlayerControlsView(player: viewModel.player, artworkData: viewModel.currentTrackArtwork)
              .fixedSize()
              .frame(maxWidth: .infinity)
              .padding([.horizontal, .bottom], 12)
          }
          .fixedSize(horizontal: false, vertical: true)
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            if !viewModel.library.isImporting, !albums.isEmpty {
              switch OS.isAppKit {
              case true:
                Button {
                  viewModel.isFolderImporterPresented = true
                } label: {
                  Label(String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle), systemImage: "folder")
                }
              case false:
                Menu {
                  Button {
                    viewModel.isFileImporterPresented = true
                  } label: {
                    Label(String(localized: "i18n:Import.ImportFiles", bundle: #bundle), systemImage: "music.note")
                  }
                  Button {
                    viewModel.isFolderImporterPresented = true
                  } label: {
                    Label(String(localized: "i18n:Import.ImportFolder", bundle: #bundle), systemImage: "folder")
                  }
                } label: {
                  Label(String(localized: "i18n:Import.ImportMusic", bundle: #bundle), systemImage: "plus")
                    .tint(.primary)
                }
              }
            }
          }
          ToolbarItem(placement: .primaryAction) {
            if !viewModel.library.isImporting, !albums.isEmpty {
              Menu {
                Picker(String(localized: "i18n:Sort.Label", bundle: #bundle), selection: $vm.albumSortOrder) {
                  ForEach(AlbumSortOrder.allCases, id: \.self) { order in
                    Text(order.localizedName).tag(order)
                  }
                }
                .pickerStyle(.inline)
              } label: {
                Label(String(localized: "i18n:Sort.Label", bundle: #bundle), systemImage: "arrow.up.arrow.down")
                  .tint(.primary)
              }
            }
          }
          #if DEBUG
          ToolbarItem(placement: .primaryAction) {
            if !viewModel.library.isImporting, !albums.isEmpty {
              Button {
                viewModel.player.stop()
                viewModel.library.clearDatabase()
              } label: {
                Label(String(localized: "i18n:Debug.ClearDatabase", bundle: #bundle), systemImage: "trash")
              }
            }
          }
          #endif
        }
    }
    #if os(macOS) || targetEnvironment(macCatalyst)
    .onDrop(of: [.fileURL, .folder], isTargeted: $vm.isDropTargeted) { providers in
      viewModel.handleDrop(providers)
    }
    #endif
    .fontWidth(.condensed)
    .tint(.madTunesAccent)
    .trackScreenVMParameters()
    .environment(viewModel)
    .onAppear {
      viewModel.library.loadPersistedData()
      viewModel.selectedPlaylistID = viewModel.library.playlists.first?.id
    }
  }

  // MARK: Private

  @State private var viewModel = MadTunesViewModel.shared
  @State private var viewColumn: NavigationSplitViewColumn = .content
  @FocusState private var isContentFocused: Bool

  // MARK: - Content Area

  @ViewBuilder
  private func contentArea(albums displayAlbums: [Album]) -> some View {
    @Bindable var vm = viewModel
    NavigationStack {
      Color.clear
        .overlay {
          AlbumGridView(
            albums: displayAlbums,
            expandedAlbumID: $vm.expandedAlbumID,
            highlightedAlbumIDs: $vm.highlightedAlbumIDs,
            selectedTrackIDs: $vm.selectedTrackIDs,
            currentTrackID: viewModel.player.currentTrack?.id,
            onTrackSelected: { track, albumTracks in
              viewModel.onTrackSelected(track, albumTracks)
            },
            onAlbumDoubleClicked: { album in
              viewModel.onAlbumDoubleClicked(album)
            }
          )
          .focusable()
          .focused($isContentFocused)
          .focusEffectDisabled()
        }
    }
    .environment(viewModel)
    .onKeyPress { press in
      viewModel.handleKeyPress(press, albums: displayAlbums)
    }
    .onChange(of: viewModel.expandedAlbumID) { _, _ in
      viewModel.selectedTrackIDs.removeAll()
    }
    .onChange(of: viewModel.highlightedAlbumIDs) { _, _ in
      isContentFocused = true
    }
    .overlay {
      LibraryContentAvailabilityOverlayView(
        displayAlbums: displayAlbums,
        selectedPlaylist: viewModel.library.playlists.first(where: { $0.id == viewModel.selectedPlaylistID })
      )
    }
  }
}

// MARK: - BottomBarBackground

private struct BottomBarBackground: View {
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let baseColor = Color.secondary
    LinearGradient(
      colors: [
        baseColor.opacity(0),
        baseColor.opacity(0.6),
        baseColor.opacity(0.7),
        baseColor.opacity(0.8),
        baseColor.opacity(0.9),
        baseColor,
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea(.all)
    .colorInvert()
  }
}
