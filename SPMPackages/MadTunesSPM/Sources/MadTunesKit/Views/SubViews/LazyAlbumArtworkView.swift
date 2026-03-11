// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

/// Artwork view with lazy loading. Shows a WinUI3ProgressRing placeholder
/// while artwork is being loaded, then transitions to the actual artwork
/// or a music-note fallback.
struct LazyAlbumArtworkView: View {
  // MARK: Internal

  let album: Album

  var body: some View {
    let key = viewModel.library.albumKey(title: album.title, artist: album.artist)
    let cachedArtwork = viewModel.library.artworkCache[key]
    let isLoading = viewModel.library.artworkLoadingKeys.contains(key)

    Group {
      if let cachedArtwork {
        ArtworkView(data: cachedArtwork)
      } else if isLoading {
        ZStack {
          LinearGradient(
            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          WinUI3ProgressRing(size: 48, lineWidth: 6)
            .tint(.secondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
      } else {
        ArtworkView(data: nil)
      }
    }
    .task {
      guard cachedArtwork == nil, let trackURL = album.tracks.first?.fileURL else { return }
      viewModel.library.requestArtworkLoad(forAlbumKey: key, sampleTrackURL: trackURL)
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var viewModel
}
