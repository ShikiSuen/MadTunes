// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPMiniPlayerBar

/// Phase 75: Compact mini player bar shown at the bottom of non-NowPlaying sections.
/// Tapping it switches to the Now Playing section.
struct WPMiniPlayerBar: View {
  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  let accentColor: Color

  var body: some View {
    Button {
      withAnimation(.interactiveSpring) {
        phoneVM.currentSection = .nowPlaying
      }
    } label: {
      VStack(spacing: 0) {
        // Progress bar at top edge.
        GeometryReader { geo in
          let fraction = vm.player.duration > 0
            ? min(max(vm.player.currentTime / vm.player.duration, 0), 1)
            : 0
          Rectangle()
            .fill(accentColor)
            .frame(width: geo.size.width * fraction, height: 2)
        }
        .frame(height: 2)

        HStack(spacing: 12) {
          // Artwork thumbnail.
          ArtworkView(data: vm.currentTrackArtwork)
            .frame(width: 40, height: 40)
            .clipShape(.rect)

          // Track info.
          VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: vm.player.currentTrack?.title ?? "—")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.white)
              .lineLimit(1)
            Text(verbatim: vm.player.currentTrack?.artist ?? "—")
              .font(.system(size: 12))
              .foregroundStyle(.white.opacity(0.6))
              .lineLimit(1)
          }

          Spacer()

          // Play/Pause button (does not navigate).
          Button {
            Task { await vm.player.togglePlayPause() }
          } label: {
            Image(systemName: vm.player.isPlaying ? "pause.fill" : "play.fill")
              .font(.system(size: 20))
              .foregroundStyle(.white)
          }
          .buttonStyle(.plain)

          // Next button.
          Button {
            Task { await vm.player.next() }
          } label: {
            Image(systemName: "forward.fill")
              .font(.system(size: 16))
              .foregroundStyle(.white.opacity(0.7))
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .background(Color.white.opacity(0.08))
    }
    .buttonStyle(.plain)
    .frame(height: 56)
  }
}
