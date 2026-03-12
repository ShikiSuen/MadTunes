// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - MadTunesMainView

struct MadTunesMainView: View {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var body: some View {
    @Bindable var vm = viewModel
    NavigationSplitView(
      columnVisibility: $vm.screenVM.splitViewVisibility,
      preferredCompactColumn: $viewColumn
    ) {
      SidebarView(library: viewModel.library, selectedPlaylistID: $vm.selectedPlaylistID)
        .background {
          Group {
            if colorScheme == .dark {
              Color.clear
            } else {
              Color.secondary.colorInvert()
            }
          }
          .ignoresSafeArea(.all)
          .trackCanvasSize(debounceDelay: 0.3) {
            let existingWidth = vm.screenVM.actualSidebarWidthObserved
            let newValue = $0.width.rounded(.up)
            guard existingWidth != newValue else { return }
            vm.screenVM.actualSidebarWidthObserved = newValue
          }
        }
        .environment(\.colorScheme, .dark)
        .navigationSplitViewColumnWidth(min: 210, ideal: 210, max: 210)
    } detail: {
      let albums = viewModel.currentAlbums
      contentArea(albums: albums)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          ZStack {
            Color.primary.opacity(0.05)
              .ignoresSafeArea(.all)
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
          .ignoresSafeArea(.all)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
          ToolbarItem(placement: .primaryAction) {
            if !viewModel.library.isImporting, !albums.isEmpty {
              Menu {
                Picker(
                  String(localized: "i18n:Search.SearchFields", bundle: #bundle),
                  selection: $vm.searchFilterMode
                ) {
                  ForEach(SearchFilterMode.allCases, id: \.self) { mode in
                    Text(mode.localizedName).tag(mode)
                  }
                }
                .pickerStyle(.inline)
              } label: {
                Label(
                  String(localized: "i18n:Search.SearchFields", bundle: #bundle),
                  systemImage: "line.3.horizontal.decrease.circle"
                )
                .tint(.primary)
              }
            }
          }
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
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var isContentFocused: Bool

  // MARK: - Content Area

  @ViewBuilder
  private func contentArea(albums displayAlbums: [Album]) -> some View {
    @Bindable var vm = viewModel
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
      .searchable(
        text: $vm.searchText,
        placement: .toolbar,
        prompt: String(localized: "i18n:Search.Prompt", bundle: #bundle)
      )
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
      .onChange(of: viewModel.selectedPlaylistID) { _, _ in
        viewModel.resetColumnBrowserFilters()
        viewModel.searchText = ""
      }
      .overlay {
        ContentAvailabilityOverlay(
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
