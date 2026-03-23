// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

/// Phase 108: Artwork view with lazy loading from SwiftData cache.
/// Each instance uses its own @State — no observable dictionary, no cascade re-renders.
struct LazyAlbumArtworkView: View {
  // MARK: Lifecycle

  init(album: Album, alwaysGlossy: Bool = false) {
    self.album = album
    self.alwaysGlossy = alwaysGlossy
  }

  // MARK: Internal

  var body: some View {
    // Phase 111: Pass pre-decoded Image instead of raw Data to avoid
    // JPEG decode on every body evaluation during scroll.
    ArtworkView(image: decodedImage, dominantColor: dominantColor, alwaysGlossy: alwaysGlossy)
      .task {
        guard decodedImage == nil, let track = album.tracks.first else { return }
        let key = vm.library.albumKey(title: album.title, artist: album.artist)
        let result = await vm.library.loadArtwork(
          forAlbumKey: key,
          sampleTrackURL: track.fileURL,
          sampleTrackBookmark: track.bookmarkData
        )
        if let result {
          decodedImage = ArtworkView.makeImage(from: result.data)
          if let h = result.dominantColorHue, let s = result.dominantColorSaturation,
             let b = result.dominantColorBrightness {
            dominantColor = Color(hue: h, saturation: s, brightness: b)
          }
        }
      }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm

  /// Phase 111: Per-view state — decode once and cache the Image, not raw Data.
  @State private var decodedImage: Image?
  @State private var dominantColor: Color?

  private let album: Album
  private let alwaysGlossy: Bool
}
