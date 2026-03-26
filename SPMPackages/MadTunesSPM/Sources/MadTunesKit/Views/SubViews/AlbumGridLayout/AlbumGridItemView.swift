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
    isCursor: Bool,
    isMultipleSelection: Bool,
    legacyHardwareMode: Bool
  ) {
    self.album = album
    self.isExpanded = isExpanded
    self.isSelected = isSelected
    self.isCursor = isCursor
    self.isMultipleSelection = isMultipleSelection
    self.legacyHardwareMode = legacyHardwareMode
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
      .padding(.horizontal, isExpanded ? 4 : 8)
      .padding(.bottom, 4)
    }
    .animation(.interactiveSpring.nerf(legacyHardwareMode), value: isExpanded)
    .background {
      if showSelectedStatus {
        selectionBackground
      }
    }
  }

  // MARK: Private

  // Phase 111: Removed @State vm to eliminate per-tile @Observable subscription.
  private let album: Album
  private let isExpanded: Bool
  private let isSelected: Bool
  private let isCursor: Bool
  private let isMultipleSelection: Bool
  private let legacyHardwareMode: Bool

  @ViewBuilder private var selectionBackground: some View {
    if isCursor {
      // Cursor item: thicker border, lower opacity
      Rectangle()
        .fill(
          LinearGradient(
            colors: [
              Color.madTunesAccent.opacity(0.15),
              Color.madTunesAccent.opacity(0.13),
              Color.madTunesAccent.opacity(0.10),
              Color.madTunesAccent.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .strokeBorder(
          LinearGradient(
            colors: [
              Color.madTunesAccent.opacity(0.8),
              Color.madTunesAccent.opacity(0.6),
              Color.madTunesAccent.opacity(0.4),
              Color.madTunesAccent.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 3.5
        )
        .allowsHitTesting(false)
    } else {
      // Regular selected item
      Rectangle()
        .fill(
          LinearGradient(
            colors: [
              Color.madTunesAccent.opacity(0.4),
              Color.madTunesAccent.opacity(0),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .allowsHitTesting(false)
    }
  }
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
