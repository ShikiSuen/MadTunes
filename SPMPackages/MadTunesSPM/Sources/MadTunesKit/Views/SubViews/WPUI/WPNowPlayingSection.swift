// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - WPNowPlayingSection

/// Phase 75: Full-screen Now Playing view in Zune/Xbox Music style.
/// Shows album artwork, track info, progress scrubber, and transport controls.
struct WPNowPlayingSection: View {
  // MARK: Internal

  var body: some View {
    GeometryReader { geo in
      let artworkSize = min(geo.size.width - 60, 320.0)
      // Phase 77: Background removed — Gradient.colorMeshGradient is now
      // applied at the Panorama hub level (WPMainView ZStack bottom).
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 16) {
          Spacer().frame(height: 12)

          // Album artwork.
          ArtworkView(data: vm.currentTrackArtworkData, alwaysGlossy: true)
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(.rect)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

          // Track info.
          VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: vm.player.currentTrack?.title ?? "—")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(2)
              .multilineTextAlignment(.center)

            Text(verbatim: vm.player.currentTrack?.artist ?? "—")
              .font(.system(size: 16))
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)

            Text(verbatim: vm.player.currentTrack?.albumTitle ?? "—")
              .font(.system(size: 14))
              .foregroundStyle(.white.opacity(0.5))
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 40)

          // Progress scrubber.
          WPProgressScrubber(
            player: vm.player,
            accentColor: phoneVM.wpAccentColor.color
          )
          .padding(.horizontal, 24)

          // Transport controls.
          WPTransportControls(player: vm.player)
            .padding(.horizontal, 40)

          // Secondary controls row.
          HStack(spacing: 36) {
            // Favorite toggle.
            Button {
              guard let track = vm.player.currentTrack else { return }
              vm.library.toggleFavorite(trackIDs: [track.id])
            } label: {
              Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundStyle(isFavorite ? .red : .white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Shuffle / Loop toggle.
            Button {
              let next: PlayLoopBehavior = switch vm.player.loopBehavior {
              case .sequential: .repeatOne
              case .repeatOne: .shuffle
              case .shuffle: .sequential
              }
              Task { await vm.player.setLoopBehavior(next) }
            } label: {
              Image(systemName: loopIcon)
                .font(.system(size: 22))
                .foregroundStyle(
                  vm.player.loopBehavior == .sequential
                    ? .white.opacity(0.6)
                    : phoneVM.wpAccentColor.color
                )
            }
            .buttonStyle(.plain)

            // Phase 78: Playing Queue button.
            Button {
              phoneVM.isQueuePresented = true
            } label: {
              Image(systemName: "list.bullet")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Phase 78: Accent Color picker button.
            Button {
              phoneVM.isAccentColorPickerPresented = true
            } label: {
              Image(systemName: "paintpalette")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
          }
          .padding(.top, 8)

          Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var vm
  @Environment(WPPhoneViewModel.self) private var phoneVM

  // MARK: - Private Helpers

  private var isFavorite: Bool {
    guard let track = vm.player.currentTrack else { return false }
    guard vm.library.playlists.count > 1 else { return false }
    let favoritesPlaylist = vm.library.playlists[1]
    return favoritesPlaylist.trackIDs.contains(track.id)
  }

  private var loopIcon: String {
    switch vm.player.loopBehavior {
    case .sequential: "repeat"
    case .repeatOne: "repeat.1"
    case .shuffle: "shuffle"
    }
  }
}

// MARK: - WPProgressScrubber

/// Compact progress bar + time labels for the WP now playing view.
struct WPProgressScrubber: View {
  // MARK: Internal

  let player: AudioPlayer
  let accentColor: Color

  var body: some View {
    VStack(spacing: 4) {
      // Slider.
      GeometryReader { geo in
        // Phase 110: scrubbing stays true during async seek to prevent visual jerk.
        let displayFraction = scrubbing ? scrubFraction : player.currentTime / player.duration
        let fraction = player.duration > 0
          ? min(max(displayFraction, 0), 1)
          : 0

        ZStack(alignment: .leading) {
          // Track background.
          Capsule()
            .fill(Color.white.opacity(0.2))
            .frame(height: 3)

          // Filled portion.
          Capsule()
            .fill(accentColor)
            .frame(width: geo.size.width * fraction, height: 3)

          // Thumb.
          Circle()
            .fill(accentColor)
            .frame(width: 14, height: 14)
            .offset(x: geo.size.width * fraction - 7)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              scrubbing = true
              scrubFraction = max(0, min(value.location.x / geo.size.width, 1))
            }
            .onEnded { _ in
              Task {
                // Phase 110: Keep scrubbing true until seek completes.
                let targetFraction = scrubFraction
                await player.seek(to: targetFraction * player.duration)
                scrubbing = false
              }
            }
        )
      }
      .frame(height: 20)

      // Time labels.
      HStack {
        Button {
          showRemainingTime.toggle()
        } label: {
          let timeText = showRemainingTime
            ? "-\(formatDuration(max(0, player.duration - player.currentTime)))"
            : formatDuration(player.currentTime)
          Text(timeText)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        Spacer()
        Text(verbatim: formatTime(player.duration))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.white.opacity(0.6))
      }
    }
  }

  // MARK: Private

  @State private var scrubbing = false
  @State private var scrubFraction: Double = 0
  @State private var showRemainingTime = false

  private func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return "\(mins):\(String(format: "%02d", secs))"
  }
}

// MARK: - WPTransportControls

/// Play/Pause, Previous, Next buttons in Metro style.
struct WPTransportControls: View {
  let player: AudioPlayer

  var body: some View {
    HStack(spacing: 44) {
      Button {
        Task { await player.previous() }
      } label: {
        Image(systemName: "backward.fill")
          .font(.system(size: 28))
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)

      Button {
        Task { await player.togglePlayPause() }
      } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 38))
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)

      Button {
        Task { await player.next() }
      } label: {
        Image(systemName: "forward.fill")
          .font(.system(size: 28))
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
    }
  }
}
