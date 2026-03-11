// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import simd
import SwiftUI

/// Overlay that shows an importing spinner (with real-time filename) or an
/// empty-library placeholder when no albums are present.
struct ContentAvailabilityOverlay: View {
  // MARK: Internal

  let displayAlbums: [Album]
  let selectedPlaylist: Playlist?

  var body: some View {
    Group {
      if viewModel.library.isImporting {
        VStack(spacing: 8) {
          let progress = viewModel.library.importProgress
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
          backgroundColorMesh
            .ignoresSafeArea()
        }
        .compositingGroup()
      } else if displayAlbums.isEmpty {
        backgroundColorMesh
          .ignoresSafeArea()
          .overlay {
            if isAllMusicPage {
              ContentUnavailableView {
                Label(String(localized: "i18n:EmptyState.NoMusic", bundle: #bundle), systemImage: "music.note")
              } description: {
                Text(String(localized: "i18n:EmptyState.ImportPrompt", bundle: #bundle))
              } actions: {
                switch OS.isAppKit {
                case true:
                  Button(String(localized: "i18n:Import.ImportFilesFolders", bundle: #bundle)) {
                    viewModel.isFolderImporterPresented = true
                  }
                  .buttonStyle(.borderedProminent)
                  .buttonBorderShape(.capsule)
                case false:
                  Button(String(localized: "i18n:Import.ImportFiles", bundle: #bundle)) {
                    viewModel.isFileImporterPresented = true
                  }
                  .buttonStyle(.borderedProminent)
                  .buttonBorderShape(.capsule)
                  Button(String(localized: "i18n:Import.ImportFolder", bundle: #bundle)) {
                    viewModel.isFolderImporterPresented = true
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
    .animation(.easeOut(duration: 0.12), value: viewModel.library.isImporting)
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var viewModel
  @State private var currentProcessingFileName: String = ""
  @State private var currentProcessingFileCount: Int = 0

  /// 是否為「All Music」頁面（playlists[0]）。
  private var isAllMusicPage: Bool {
    guard let playlist = selectedPlaylist else { return true }
    return playlist.id == viewModel.library.playlists.first?.id
  }

  /// 是否為「Favorites」頁面。
  private var isFavoritesPage: Bool {
    guard let playlist = selectedPlaylist,
          viewModel.library.playlists.count > 1 else { return false }
    return playlist.id == viewModel.library.playlists[1].id
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

  private var angularColorGradient: AngularGradient {
    AngularGradient(
      gradient: Gradient(stops: [
        .init(color: Color(hue: 3 / 6, saturation: 1, brightness: 1), location: 0.0 / 6),
        .init(color: Color(hue: 4 / 6, saturation: 1, brightness: 1), location: 1.0 / 6),
        .init(color: Color(hue: 5 / 6, saturation: 1, brightness: 1), location: 2.0 / 6),
        .init(color: Color(hue: 6 / 6, saturation: 1, brightness: 1), location: 3.0 / 6),
        .init(color: Color(hue: 0 / 6, saturation: 1, brightness: 1), location: 4.0 / 6),
        .init(color: Color(hue: 1 / 6, saturation: 1, brightness: 1), location: 5.0 / 6),
        .init(color: Color(hue: 2 / 6, saturation: 1, brightness: 1), location: 1.0),
      ]),
      center: .center
    )
  }

  @ViewBuilder private var backgroundColorMesh: some View {
    Group {
      if #available(macOS 15.0, iOS 18.0, *) {
        MeshGradient(
          width: 2,
          height: 2,
          points: [
            SIMD2(0.0, 0.0), // Top-left
            SIMD2(1.0, 0.0), // Top-right
            SIMD2(0.0, 1.0), // Bottom-left
            SIMD2(1.0, 1.0), // Bottom-right
          ],
          colors: [
            .red,
            .blue,
            .green,
            .purple,
          ]
        )
        .opacity(0.3)
        .background {
          Color.primary.colorInvert()
        }
      } else {
        angularColorGradient
          .blur(radius: 8)
          .opacity(0.3)
          .background {
            Color.primary.colorInvert()
          }
      }
    }
  }
}
