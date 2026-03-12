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

  var body: some View {
    let showSelectedStatus = isSelected && !isExpanded
    VStack(alignment: .leading, spacing: isExpanded ? 6 : 0) {
      Rectangle()
        .fill(Color.clear)
        .aspectRatio(1, contentMode: .fit)
        .overlay {
          LazyAlbumArtworkView(album: album, alwaysGlossy: true)
            .compositingGroup()
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect)
            .shadow(radius: isExpanded ? 6 : 3, y: 2)
            .overlay(alignment: .topLeading) {
              if isMultipleSelection, !isExpanded {
                MultiSelectionBadge()
              }
            }
            // shrink slightly when not expanded, keeping centered
            .scaleEffect(isExpanded ? 1 : 0.92, anchor: .center)
        }

      VStack(alignment: .leading, spacing: 3) {
        Text(album.title)
          .frame(maxWidth: .infinity, alignment: .leading)
          .font(isExpanded ? .headline : .subheadline)
          .fontWeight(.semibold)
          .lineLimit(1)

        if !isExpanded {
          Text(album.artist)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .drawingGroup()
      .padding(.horizontal, isExpanded ? 4 : 8)
      .padding(.bottom, 4)
    }
    .animation(.easeInOut(duration: 0.2), value: isExpanded)
    .background {
      if showSelectedStatus {
        Rectangle()
          .fill(Color.madTunesAccent.opacity(0.1))
          .stroke(
            Color.madTunesAccent.opacity(0.15),
            lineWidth: 1
          )
          .allowsHitTesting(false)
      }
    }
  }

  // MARK: Private

  private let album: Album
  private let isExpanded: Bool
  private let isSelected: Bool
  private let isMultipleSelection: Bool
}

// MARK: - MultiSelectionBadge

/// A triangle corner badge indicating multi-selected album.
private struct MultiSelectionBadge: View {
  // MARK: Lifecycle

  init() {}

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
