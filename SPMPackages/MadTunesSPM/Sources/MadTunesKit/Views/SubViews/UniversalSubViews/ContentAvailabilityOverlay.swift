// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import simd
import SwiftUI

/// Overlay that shows an importing spinner (with real-time filename) or an
/// empty-library placeholder when no albums are present.
struct ContentAvailabilityOverlay: View {
  // MARK: Lifecycle

  init(
    displayAlbums: [Album],
    selectedPlaylist: Playlist?
  ) {
    self.displayAlbums = displayAlbums
    self.selectedPlaylist = selectedPlaylist
  }

  // MARK: Internal

  var body: some View {
    Group {
      if vm.library.isImporting {
        VStack(spacing: 8) {
          let progress = vm.library.importProgress
          let hasFileImporting = progress.totalCount > 0
          let finished = progress.finishedCount
          let total = progress.totalCount
          let percent = total > 0 ? finished * 100 / total : 0
          WinUI3ProgressRing(size: 64, lineWidth: 7)
            .tint(.primary)
            .overlay {
              if hasFileImporting {
                Text(verbatim: "\(percent)%")
                  .font(.title)
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
              }
            }
          Text(String(localized: "i18n:Import.ImportingMusic", bundle: #bundle))
          if !progress.fileName.isEmpty {
            Text(progress.fileName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          // Show the "currentlyFinishedFileCount/TotalCount" here with a trailing integer percent.
          if hasFileImporting {
            Text(verbatim: "\(finished)/\(total)")
              .font(.caption)
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          Gradient.ColorMeshGradient
            .ignoresSafeArea()
        }
        .compositingGroup()
      } else if !vm.library.hasLoadedPersistence {
        Gradient.ColorMeshGradient
          .ignoresSafeArea()
          .overlay {
            ContentUnavailableView {
              WinUI3ProgressRing(size: 96, lineWidth: 7)
                .tint(.primary)
                .overlay {
                  Image(systemName: "internaldrive")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)
                    .foregroundStyle(.secondary)
                }
            }
          }
          .compositingGroup()
      } else if vm.isSearching {
        Gradient.ColorMeshGradient
          .ignoresSafeArea()
          .overlay {
            ContentUnavailableView {
              WinUI3ProgressRing(size: 96, lineWidth: 7)
                .tint(.primary)
                .overlay {
                  Image(systemName: "waveform.badge.magnifyingglass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)
                    .foregroundStyle(.secondary)
                }
            }
          }
          .compositingGroup()
      } else if displayAlbums.isEmpty {
        Gradient.ColorMeshGradient
          .ignoresSafeArea()
          .overlay {
            if hasActiveFilters {
              ContentUnavailableView {
                Label(
                  String(localized: "i18n:EmptyState.NoFilterResults", bundle: #bundle),
                  systemImage: "music.note"
                )
              } description: {
                Text(
                  String(localized: "i18n:EmptyState.PleaseChangeFilter", bundle: #bundle)
                )
              }
            } else if isAllMusicPage {
              ContentUnavailableView {
                Label(String(localized: "i18n:EmptyState.NoMusic", bundle: #bundle), systemImage: "music.note")
              } description: {
                Text(String(localized: "i18n:EmptyState.ImportPrompt", bundle: #bundle))
              } actions: {
                switch OS.isAppKit {
                case true:
                  Button(String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle)) {
                    vm.isFolderImporterPresented = true
                  }
                  .buttonStyle(.borderedProminent)
                  .buttonBorderShape(.capsule)
                case false:
                  Button(String(localized: "i18n:Import.ImportFiles", bundle: #bundle)) {
                    vm.isFileImporterPresented = true
                  }
                  .buttonStyle(.borderedProminent)
                  .buttonBorderShape(.capsule)
                  Button(String(localized: "i18n:Import.ImportFolder", bundle: #bundle)) {
                    vm.isFolderImporterPresented = true
                  }
                  .buttonStyle(.borderedProminent)
                  .buttonBorderShape(.capsule)
                }
              }
            } else {
              ContentUnavailableView {
                Label(playlistEmptyTitle, systemImage: playlistEmptyIcon)
              } description: {
                Text(playlistEmptyDescription)
              }
            }
          }
          .compositingGroup()
      }
    }
    .animation(.easeOut(duration: 0.12), value: vm.library.hasLoadedPersistence)
    .animation(.easeOut(duration: 0.12), value: vm.isSearching)
    .animation(.easeOut(duration: 0.12), value: vm.library.isImporting)
    .animation(.easeOut(duration: 0.12), value: hasActiveFilters)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @State private var currentProcessingFileName: String = ""
  @State private var currentProcessingFileCount: Int = 0

  private let displayAlbums: [Album]
  private let selectedPlaylist: Playlist?

  /// 是否為「All Music」頁面（playlists[0]）。
  private var isAllMusicPage: Bool {
    guard let playlist = selectedPlaylist else { return true }
    return playlist.id == vm.library.playlists.first?.id
  }

  /// 是否為「Favorites」頁面。
  private var isFavoritesPage: Bool {
    guard let playlist = selectedPlaylist,
          vm.library.playlists.count > 1 else { return false }
    return playlist.id == vm.library.playlists[1].id
  }

  /// Phase 51: 是否有活動的篩選條件（搜尋文字或 Column Browser 篩選）。
  private var hasActiveFilters: Bool {
    let hasSearchText = !searchTokens(from: vm.searchText).isEmpty
    let hasColumnBrowserFilter = vm.isColumnBrowserFiltering
    return hasSearchText || hasColumnBrowserFilter
  }

  private var playlistEmptyTitle: String {
    if isFavoritesPage {
      return String(localized: "i18n:EmptyState.NoFavorites", bundle: #bundle)
    }
    return String(localized: "i18n:EmptyState.EmptyPlaylist", bundle: #bundle)
  }

  private var playlistEmptyIcon: String {
    if isFavoritesPage {
      return "heart.slash"
    }
    return "music.note"
  }

  private var playlistEmptyDescription: String {
    if isFavoritesPage {
      return String(localized: "i18n:EmptyState.FavoritesDescription", bundle: #bundle)
    }
    if let name = selectedPlaylist?.name {
      return String(
        localized: "i18n:EmptyState.PlaylistEmptyDescription",
        defaultValue: "\"\(name)\" has no tracks. Add songs from the context menu.",
        bundle: #bundle
      )
    }
    return String(localized: "i18n:EmptyState.PlaylistNoTracksYet", bundle: #bundle)
  }
}
