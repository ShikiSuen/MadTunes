// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import MadTunesTips
import SwiftUI

// MARK: - DesktopMainView

struct DesktopMainView: View {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var body: some View {
    NavigationSplitView(
      columnVisibility: Bindable(vm).screenVM.splitViewVisibility,
      preferredCompactColumn: $viewColumn
    ) {
      SidebarView(library: vm.library, selectedPlaylistID: $vm.selectedPlaylistID)
        .disabled(vm.library.isImporting)
        .saturation(vm.library.isImporting ? 0 : 1)
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
        .environment(\.colorScheme, OS.liquidGlassThemeSuspected ? .dark : colorScheme)
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
          Color(white: colorScheme == .dark ? 0.15 : 0.95)
            .ignoresSafeArea(.all)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          // 此區域高度固定為 `72 * ThisDevice.uiFactor`。
          ZStack {
            Group {
              Group {
                if #available(macOS 26.0, iOS 26.0, *), OS.liquidGlassThemeSuspected {
                  Rectangle()
                    .glassEffect(.regular, in: .rect)
                } else {
                  Rectangle()
                    .fill(.ultraThinMaterial)
                }
              }
              .mask {
                BottomBarMask()
              }
              .ignoresSafeArea(.all)
              BottomBarBackground()
            }
            PlayerControlsView(player: vm.player, artworkData: vm.currentTrackArtworkData)
              .fixedSize()
              .frame(maxWidth: .infinity)
              .padding([.horizontal, .bottom], 12 * vm.uiFactor)
          }
          .fixedSize(horizontal: false, vertical: true)
          .trackCanvasSize(debounceDelay: 0.3) {
            let newValue = $0.height.rounded(.up)
            guard vm.screenVM.bottomSafeAreaInsetHeight != newValue else { return }
            vm.screenVM.bottomSafeAreaInsetHeight = newValue
          }
        }
        .toolbar {
          ToolbarItem(placement: .navigation) {
            if !vm.library.isImporting {
              Menu {
                switch OS.isAppKit {
                case true:
                  Button {
                    vm.isFolderImporterPresented = true
                  } label: {
                    Label(String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle), systemImage: "folder")
                      .tint(.primary)
                  }
                case false:
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
                }
                // Phase 160: New Folder Playlist shortcut in import menu.
                Divider()
                Button {
                  vm.isImporterForFolderPlaylistPresented = true
                } label: {
                  Label(
                    String(localized: "i18n:Sidebar.NewFolderPlaylist", bundle: #bundle),
                    systemImage: "folder.fill"
                  )
                }
                // Phase 164: Reapprove Sandbox Privileges.
                Divider()
                Button {
                  vm.isReapproveSandboxDialogPresented = true
                } label: {
                  Label(
                    String(localized: "i18n:Import.ReapproveSandboxPrivileges", bundle: #bundle),
                    systemImage: "lock.open"
                  )
                }
              } label: {
                Label(String(localized: "i18n:Import.ImportMusic", bundle: #bundle), systemImage: "folder")
              }
              .tint(.primary)
            }
          }

          // Phase 69: Edit/Done button for iOS multi-select on static playlists.
          #if !(canImport(AppKit) && !canImport(UIKit))

          if #available(iOS 26.0, macCatalyst 26.0, macOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .navigation)
          }

          ToolbarItem(placement: .navigation) {
            if vm.desktopContentLayout == .asTableView, vm.tableVM.canEnterEditMode {
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
            Picker(selection: $vm.desktopContentLayout) {
              Label {
                Text("i18n:Toolbar.ViewHGrid", bundle: #bundle)
              } icon: {
                Image(systemName: "inset.filled.topleading.bottomleading.trailinghalf.rectangle")
              }
              .tag(DesktopContentLayout.asAlbumHGrid)
              Label {
                Text("i18n:Toolbar.ViewVGrid", bundle: #bundle)
              } icon: {
                Image(systemName: "inset.filled.topleft.topright.bottomhalf.rectangle")
              }
              .tag(DesktopContentLayout.asAlbumVGrid)
              Label {
                Text("i18n:Toolbar.ViewTable", bundle: #bundle)
              } icon: {
                Image(systemName: "tablecells")
              }
              .tag(DesktopContentLayout.asTableView)
            } label: {
              Text(String(localized: "i18n:Toolbar.ToggleViewLayout", bundle: #bundle))
            }
            .pickerStyle(.segmented)
            .tint(.primary)
            .fixedSize()
            .popoverTip(
              vm.tutorialTips.currentTip as? Tip4GridLayout,
              arrowEdge: .top
            )
          }
          .removeSharedBackgroundVisibility(bypassWhen: OS.isAppKit)

          ToolbarItem(placement: .primaryAction) {
            if !vm.library.tracks.isEmpty {
              switch vm.desktopContentLayout {
              case .asAlbumHGrid, .asAlbumVGrid:
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
              case .asTableView:
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
        switch vm.desktopContentLayout {
        case .asTableView:
          AlbumTableView()
            // Use selectedPlaylistID as stable identity so SwiftUI fully
            // recreates the List when switching playlists (avoids an expensive
            // 5k-item diff) while keeping the view stable for other changes
            // like selection or playback updates.
            .id(vm.selectedPlaylistID)
            .focusable()
            .focused($isContentFocused)
            .focusEffectDisabled()
        case .asAlbumVGrid:
          AlbumVGrid.VerticalAlbumGridView()
            .focusable()
            .focused($isContentFocused)
            .focusEffectDisabled()
        case .asAlbumHGrid:
          AlbumHGrid.HorizontalAlbumGridView()
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
        switch vm.desktopContentLayout {
        case .asTableView:
          return vm.tableVM.handleKeyPress(press)
        case .asAlbumVGrid:
          return vm.gridVM.handleKeyPress(press, albums: displayAlbums)
        case .asAlbumHGrid:
          return vm.gridVM.handleHGridKeyPress(press, albums: displayAlbums)
        }
      }
      // Phase 96: highlightedAlbumIDs change still needs focus management (UI-only).
      .onChange(of: vm.gridVM.highlightedAlbumIDs) { _, _ in
        isContentFocused = true
      }
      // Phase 141: Search input should immediately leave table edit mode.
      .onChange(of: vm.searchText) { _, newValue in
        let hasSearchText = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSearchText, vm.tableVM.isEditModeActive {
          vm.tableVM.isEditModeActive = false
        }
      }
      // Phase 141: Active Column Browser rules should also leave table edit mode.
      .onChange(of: vm.isColumnBrowserFiltering) { _, isFiltering in
        if isFiltering, vm.tableVM.isEditModeActive {
          vm.tableVM.isEditModeActive = false
        }
      }
      .overlay {
        ContentAvailabilityOverlay(
          displayAlbums: displayAlbums,
          selectedPlaylist: vm.library.playlists.first(where: { $0.id == vm.selectedPlaylistID })
        )
      }
  }
}

// MARK: - BottomBarMask

private struct BottomBarMask: View {
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let baseColor = Color.primary
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

// MARK: - BottomBarBackground

private struct BottomBarBackground: View {
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let baseColor = Color.primary
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
