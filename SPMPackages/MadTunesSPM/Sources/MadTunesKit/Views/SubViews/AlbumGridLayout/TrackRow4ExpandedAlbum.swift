// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TrackRow4ExpandedAlbum

struct TrackRow4ExpandedAlbum: View {
  // MARK: Lifecycle

  init(
    track: Track,
    hideArtist: Bool = false,
    showDiscNumber: Bool = false,
    isPlaying: Bool = false,
    isSelected: Bool = false
  ) {
    self.track = track
    self.hideArtist = hideArtist
    self.showDiscNumber = showDiscNumber
    self.isPlaying = isPlaying
    self.isSelected = isSelected
  }

  // MARK: Internal

  var body: some View {
    HStack(spacing: 8) {
      if isPlaying {
        Image(systemName: "speaker.wave.2.fill")
          .frame(width: 32 * vm.uiFactor, alignment: .trailing)
          .foregroundStyle(Color.madTunesAccent)
          .font(.caption)
      } else {
        Text(trackNumberLabel)
          .frame(width: 32 * vm.uiFactor, alignment: .trailing)
          .foregroundStyle(.secondary)
          .font(.callout.monospacedDigit())
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(track.title)
          .font(.callout)
          .lineLimit(1)
        if !hideArtist {
          Text(track.artist)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      Text(formatDuration(track.duration))
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 52 * vm.uiFactor, alignment: .trailing)
    }
    .padding(.vertical, 6 * vm.uiFactor)
    .padding(.horizontal, 8 * vm.uiFactor)
    .background(
      RoundedRectangle(cornerRadius: 4 * vm.uiFactor)
        .fill(trackRowBackground)
    )
    .onHover { hovered in
      Task { @MainActor in
        isHovered = hovered
      }
    }
  }

  // MARK: Private

  @State private var isHovered: Bool = false
  @State private var vm: MadTunesViewModel = .shared

  private let track: Track
  private var hideArtist: Bool = false
  private var showDiscNumber: Bool = false
  private var isPlaying: Bool = false
  private var isSelected: Bool = false

  private var trackRowBackground: Color {
    if isSelected {
      return Color.madTunesAccent.opacity(0.15)
    } else if isHovered {
      return Color.primary.opacity(0.05)
    }
    return Color.clear
  }

  private var trackNumberLabel: String {
    if track.trackNumber <= 0 { return " " }
    if showDiscNumber {
      return "\(track.discNumber)-\(track.trackNumber)"
    }
    return "\(track.trackNumber)"
  }
}
