// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

/// Artwork view with lazy loading. Shows a WinUI3ProgressRing placeholder
/// while artwork is being loaded, then transitions to the actual artwork
/// or a music-note fallback.
struct LazyAlbumArtworkView: View {
  // MARK: Lifecycle

  init(album: Album, alwaysGlossy: Bool = false) {
    self.album = album
    self.alwaysGlossy = alwaysGlossy
  }

  // MARK: Internal

  var body: some View {
    let key = vm.library.albumKey(title: album.title, artist: album.artist)
    let cachedArtwork = vm.library.artworkCache[key]
    // let isLoading = viewModel.library.artworkLoadingKeys.contains(key)

    ArtworkView(data: cachedArtwork, alwaysGlossy: alwaysGlossy)
      .task {
        guard cachedArtwork == nil, let track = album.tracks.first else { return }
        vm.library.requestArtworkLoad(
          forAlbumKey: key,
          sampleTrackURL: track.fileURL,
          sampleTrackBookmark: track.bookmarkData
        )
      }
      .animation(
        .interactiveSpring.nerf(vm.gridVM.legacyHardwareMode),
        value: cachedArtwork?.hashValue
      )
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm

  private let album: Album
  private let alwaysGlossy: Bool
}
