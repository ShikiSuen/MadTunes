// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

struct ReusableAlbumExpansionBackground: View {
  // MARK: Lifecycle

  init(album: Album?) {
    self.album = album
    self.artworkData = nil
  }

  init(artworkData: Image?) {
    self.artworkData = artworkData
    self.album = nil
  }

  // MARK: Internal

  var body: some View {
    let baseColor = Color(white: colorScheme == .dark ? 0 : 1)
    LinearGradient(
      colors: [
        baseColor.opacity(0.5),
        baseColor.opacity(0),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .background {
      Group {
        if let album {
          LazyAlbumArtworkView(album: album)
        } else if let artworkData {
          ArtworkView(image: artworkData)
        } else {
          Gradient.colorMeshGradient
        }
      }
      .aspectRatio(contentMode: .fill)
      .blur(radius: 24 * ThisDevice.uiFactor)
      .opacity(0.15)
    }
    .clipped()
  }

  // MARK: Private

  @Environment(\.colorScheme) private var colorScheme

  private let album: Album?
  private let artworkData: Image?
}
