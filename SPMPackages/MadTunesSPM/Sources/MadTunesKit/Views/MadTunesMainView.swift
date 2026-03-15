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
    NavigationSplitView(
      columnVisibility: Bindable(vm).screenVM.splitViewVisibility,
      preferredCompactColumn: $viewColumn
    ) {
      SidebarView(library: vm.library, selectedPlaylistID: $vm.selectedPlaylistID)
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
        .navigationSplitViewColumnWidth(
          min: 210 * vm.uiFactor,
          ideal: 210 * vm.uiFactor,
          max: 210 * vm.uiFactor
        )
    } detail: {
      let albums = vm.gridVM.currentAlbumsDisplayed
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
                    vm.importURLs(urls)
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
                    vm.importURLs(urls)
                  }
                }
              Color.clear
                .fileImporter(
                  isPresented: $vm.isFolderImporterPresented,
                  allowedContentTypes: SupportedFormats.folderImportTypes,
                  allowsMultipleSelection: true
                ) { result in
                  if case let .success(urls) = result {
                    vm.importURLs(urls)
                  }
                }
            }
          }
          .ignoresSafeArea(.all)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          ZStack {
            BottomBarBackground()
            PlayerControlsView(player: vm.player, artworkData: vm.currentTrackArtwork)
              .fixedSize()
              .frame(maxWidth: .infinity)
              .padding([.horizontal, .bottom], 12)
          }
          .fixedSize(horizontal: false, vertical: true)
        }
        .toolbar {
          ToolbarItem(placement: .navigation) {
            if !vm.library.isImporting {
              switch OS.isAppKit {
              case true:
                Button {
                  vm.isFolderImporterPresented = true
                } label: {
                  Label(String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle), systemImage: "folder")
                    .tint(.primary)
                }
                .tint(.primary)
              case false:
                Menu {
                  Button {
                    vm.isFileImporterPresented = true
                  } label: {
                    Label(String(localized: "i18n:Import.ImportFiles", bundle: #bundle), systemImage: "music.note")
                  }
                  Button {
                    vm.isFolderImporterPresented = true
                  } label: {
                    Label(String(localized: "i18n:Import.ImportFolder", bundle: #bundle), systemImage: "folder")
                  }
                } label: {
                  Label(String(localized: "i18n:Import.ImportMusic", bundle: #bundle), systemImage: "plus")
                    .tint(.primary)
                }
                .tint(.primary)
              }
            }
          }

          // Phase 69: Edit/Done button for iOS multi-select on static playlists.
          #if !(canImport(AppKit) && !canImport(UIKit))

          if #available(iOS 26.0, macCatalyst 26.0, macOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .navigation)
          }

          ToolbarItem(placement: .navigation) {
            if vm.useTableView, vm.tableVM.canEnterEditMode {
              Button {
                withAnimation {
                  vm.tableVM.isEditModeActive.toggle()
                }
              } label: {
                Label(
                  vm.tableVM.isEditModeActive
                    ? String(localized: "i18n:Common.Done", bundle: #bundle)
                    : String(localized: "i18n:Common.Edit", bundle: #bundle),

                  systemImage: "square.and.pencil"
                )
                .tint(.primary)
              }
              .tint(.primary)
            }
          }
          #endif

          // Phase 68: Button for showing the popover of hotkey hints
          ToolbarItem(placement: .automatic) {
            HotKeyHintView()
          }

          // Phase 41: view mode toggle should come first
          ToolbarItem(placement: .primaryAction) {
            Picker(selection: $vm.useTableView) {
              Label(String(localized: "i18n:Toolbar.ViewGrid", bundle: #bundle), systemImage: "square.grid.2x2")
                .tag(false)
              Label(String(localized: "i18n:Toolbar.ViewTable", bundle: #bundle), systemImage: "tablecells")
                .tag(true)
            } label: {
              Text(String(localized: "i18n:Toolbar.ToggleViewLayout", bundle: #bundle))
            }
            .pickerStyle(.segmented)
            .tint(.primary)
            .fixedSize()
            .onChange(of: vm.useTableView) { _, newValue in
              UserDefaults.standard.set(newValue, forKey: "MadTunes.useTableView")
              vm.tableVM.isEditModeActive = false
              Task {
                if newValue {
                  // when entering table mode we no longer need an expanded album
                  vm.gridVM.expandedAlbumID = nil
                  vm.gridVM.highlightedAlbumIDs.removeAll()
                  vm.selectedTrackIDs.removeAll()
                }
              }
            }
          }
          .removeSharedBackgroundVisibility(bypassWhen: OS.isAppKit)

          ToolbarItem(placement: .primaryAction) {
            if !vm.library.tracks.isEmpty {
              switch vm.useTableView {
              case false:
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
                .tint(.primary)
                .disabled(vm.library.isImporting)
              case true:
                Menu {
                  ForEach(TableColumnType.allCases.filter(\.isHidable)) { column in
                    Toggle(column.localizedName, isOn: Binding(
                      get: { vm.tableVM.isColumnVisible(column) },
                      set: { _ in vm.tableVM.toggleColumnVisibility(column) }
                    ))
                  }
                } label: {
                  Label(
                    String(localized: "i18n:Table.ColumnFilter.ToolbarButtonTitle", bundle: #bundle),
                    systemImage: "tablecells.badge.ellipsis"
                  )
                  .tint(.primary)
                }
                .tint(.primary)
              }
            }
          }

          if #available(iOS 26.0, macCatalyst 26.0, macOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .primaryAction)
          }

          ToolbarItem(placement: .primaryAction) {
            if (!vm.library.isImporting && !albums.isEmpty) || !searchTokens(from: vm.searchText).isEmpty {
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
              .tint(.primary)
            }
          }
        }
    }
    #if os(macOS) || targetEnvironment(macCatalyst)
    .onDrop(of: [.fileURL, .folder], isTargeted: $vm.isDropTargeted) { providers in
      vm.handleDrop(providers)
    }
    #endif
    .fontWidth(.condensed)
    .tint(.madTunesAccent)
    .trackScreenVMParameters()
    .environment(vm)
    .task {
      await vm.library.loadPersistedData()
      vm.selectedPlaylistID = vm.library.playlists.first?.id
    }
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared
  @State private var viewColumn: NavigationSplitViewColumn = .content
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var isContentFocused: Bool

  // MARK: - Content Area

  @ViewBuilder
  private func contentArea(albums displayAlbums: [Album]) -> some View {
    Color.clear
      .overlay(alignment: .leading) {
        if vm.useTableView {
          AlbumTableView()
            // Use selectedPlaylistID as stable identity so SwiftUI fully
            // recreates the List when switching playlists (avoids an expensive
            // 5k-item diff) while keeping the view stable for other changes
            // like selection or playback updates.
            .id(vm.selectedPlaylistID)
            .focusable()
            .focused($isContentFocused)
            .focusEffectDisabled()
        } else {
          AlbumGridView()
            .focusable()
            .focused($isContentFocused)
            .focusEffectDisabled()
        }
      }
      .searchable(
        text: $vm.searchText,
        placement: .toolbar,
        prompt: String(localized: "i18n:Search.Prompt", bundle: #bundle)
      )
      .task(id: vm.searchText) {
        // Lightweight async observation hook: keep a short, cancelable delay so
        // UI can coordinate with the ViewModel's debounced background search.
        do { try await Task.sleep(nanoseconds: 50_000_000) } catch { /* cancelled */ }
      }
      .environment(vm)
      .onKeyPress { press in
        // Phase 63: Dispatch directly to sub-VMs.
        if vm.useTableView {
          return vm.tableVM.handleKeyPress(press)
        } else {
          return vm.gridVM.handleKeyPress(press, albums: displayAlbums)
        }
      }
      .onChange(of: vm.gridVM.expandedAlbumID) { _, _ in
        vm.selectedTrackIDs.removeAll()
      }
      .onChange(of: vm.gridVM.highlightedAlbumIDs) { _, _ in
        isContentFocused = true
      }
      .onChange(of: vm.selectedPlaylistID) { _, _ in
        if !vm.selectedTrackIDs.isEmpty { vm.selectedTrackIDs.removeAll() }
        vm.tableVM.isEditModeActive = false
        vm.resetColumnBrowserFilters()
        if !searchTokens(from: vm.searchText).isEmpty {
          vm.searchText = ""
        }
      }
      // Phase 43: Ensure artwork is loaded when playing from table view.
      .onChange(of: vm.player.currentTrack?.id) { _, _ in
        guard let track = vm.player.currentTrack else { return }
        let key = vm.library.albumKey(title: track.albumTitle, artist: track.albumArtist)
        vm.library.requestArtworkLoad(forAlbumKey: key, sampleTrackURL: track.fileURL)
      }
      .overlay {
        ContentAvailabilityOverlay(
          displayAlbums: displayAlbums,
          selectedPlaylist: vm.library.playlists.first(where: { $0.id == vm.selectedPlaylistID })
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
