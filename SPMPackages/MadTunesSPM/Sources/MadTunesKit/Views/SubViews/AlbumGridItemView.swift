// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - AlbumGridItemView

/// A single album tile in the grid: artwork + title + artist.
struct AlbumGridItemView: View {
  // MARK: Lifecycle

  init(
    album: Album,
    isExpanded: Bool,
    isSelected: Bool,
    isMultipleSelection: Bool
  ) {
    self.album = album
    self.isExpanded = isExpanded
    self.isSelected = isSelected
    self.isMultipleSelection = isMultipleSelection
  }

  // MARK: Internal

  let album: Album
  let isExpanded: Bool
  let isSelected: Bool
  let isMultipleSelection: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      let showOverlayStroke = isMultipleSelection || isExpanded || isSelected
      LazyAlbumArtworkView(album: album)
        .aspectRatio(1, contentMode: .fit)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              angularColorGradient,
              lineWidth: showOverlayStroke ? 12 : 0
            )
            .shadow(radius: showOverlayStroke ? 6 : 3, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: isExpanded ? 6 : 3, y: 2)
        .overlay(alignment: .topLeading) {
          if isMultipleSelection, !isExpanded {
            MultiSelectionBadge()
          }
        }

      VStack(alignment: .leading, spacing: 3) {
        Text(album.title)
          .font(.subheadline)
          .fontWeight(.medium)
          .lineLimit(1)

        Text(album.artist)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .padding([.horizontal, .bottom], 4)
    }
  }

  // MARK: Private

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
}

// MARK: - MultiSelectionBadge

/// A triangle corner badge indicating multi-selected album.
private struct MultiSelectionBadge: View {
  // MARK: Internal

  var body: some View {
    ZStack(alignment: .topLeading) {
      Triangle()
        .fill(Color.red)
        .frame(width: size, height: size)
      Image(systemName: "checkmark.diamond.fill")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
        .offset(x: 3, y: 3)
        .contentShape(.circle)
        .frame(width: size - 4, height: size - 4, alignment: .topLeading)
    }
  }

  // MARK: Private

  private let size: CGFloat = 36
}

// MARK: - Triangle

private struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: rect.minX, y: rect.minY))
      p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
      p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      p.closeSubpath()
    }
  }
}
