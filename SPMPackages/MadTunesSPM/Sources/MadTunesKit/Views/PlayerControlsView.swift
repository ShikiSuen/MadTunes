// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PlayerControlsView

/// Bottom bar with playback transport, progress scrubber, volume, and now-playing info.
struct PlayerControlsView: View {
  // MARK: Lifecycle

  init(player: AudioPlayer, artworkData: Data? = nil, sansBezel: Bool = false) {
    self.player = player
    self.artworkData = artworkData
    self.sansBezel = sansBezel
  }

  // MARK: Internal

  var player: AudioPlayer
  var artworkData: Data?

  var sansBezel = false

  var body: some View {
    if sansBezel {
      coreComponent
        .padding(.horizontal, 24)
    } else {
      coreComponent
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .modifier(GlassEffectModifier())
    }
  }

  @ViewBuilder var coreComponent: some View {
    HStack(spacing: 16) {
      let artWorkViewHeight: Double = sansBezel ? 28 : 40
      ArtworkView(data: artworkData)
        .frame(width: artWorkViewHeight, height: artWorkViewHeight)
      VStack(spacing: 0) {
        // Progress scrubber
        let scrubber = ProgressScrubber(
          currentTime: player.currentTime,
          duration: player.duration,
          onSeek: { player.seek(to: $0) }
        )
        .frame(minWidth: 640)
        HStack(spacing: 16) {
          // Transport controls (centre)
          transportControls
          // Now-playing info (left)
          nowPlayingInfo
            .frame(maxWidth: .infinity, alignment: .center)

          // Time + volume (right)
          timeAndVolume
        }
        .frame(height: sansBezel ? 26 : 34)
        scrubber
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(minHeight: 40, alignment: .center)
  }

  // MARK: Private

  private var volumeIcon: String {
    if player.volume <= 0 { return "speaker.slash.fill" }
    if player.volume < 0.33 { return "speaker.wave.1.fill" }
    if player.volume < 0.66 { return "speaker.wave.2.fill" }
    return "speaker.wave.3.fill"
  }

  // MARK: - Subviews

  @ViewBuilder private var nowPlayingInfo: some View {
    HStack(spacing: 10) {
      if let track = player.currentTrack {
        VStack(alignment: .center, spacing: 1) {
          Text(track.title)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(1)
          Text(track.artist)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } else {
        Text("Not Playing")
          .foregroundStyle(.secondary)
          .font(.callout)
      }
    }
  }

  @ViewBuilder private var transportControls: some View {
    HStack(spacing: 4) {
      Button { player.previous() } label: {
        Image(systemName: "backward.fill")
          .font(.title3)
          .frame(width: 32, height: 32)
          .contentShape(.rect)
      }
      Button { player.togglePlayPause() } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.title)
          .frame(width: 32, height: 32)
          .contentShape(.rect)
      }
      Button { player.next() } label: {
        Image(systemName: "forward.fill")
          .font(.title3)
          .frame(width: 32, height: 32)
          .contentShape(.rect)
      }
    }
    .buttonStyle(.plain)
    .buttonBorderShape(.circle)
    .padding(.leading, 8)
    .frame(maxHeight: sansBezel ? 15 : 35)
  }

  @ViewBuilder private var timeAndVolume: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        Text(formatDuration(player.currentTime))
          .font(.caption.monospacedDigit())
        Text("/")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Text(formatDuration(player.duration))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        Image(systemName: volumeIcon)
          .font(.caption)
          .frame(width: 16)

        Slider(
          value: Binding<Double>(
            get: { Double(player.volume) },
            set: { player.setVolume(Float($0)) }
          ),
          in: 0 ... 1
        )
        .frame(width: 80)
        .controlSize(.mini)
      }
    }
  }
}

// MARK: - ProgressScrubber

struct ProgressScrubber: View {
  // MARK: Internal

  let currentTime: TimeInterval
  let duration: TimeInterval
  let onSeek: (TimeInterval) -> Void

  var body: some View {
    GeometryReader { geometry in
      let fraction = duration > 0
        ? (isDragging ? dragValue : currentTime) / duration
        : 0
      let clampedFraction = min(max(fraction, 0), 1)

      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.gray.opacity(0.25))
        Rectangle()
          .fill(Color.madTunesAccent)
          .frame(width: geometry.size.width * clampedFraction)
      }
      .frame(height: isDragging ? 6 : 3, alignment: .center)
      .contentShape(Rectangle().size(width: geometry.size.width, height: 12))
      .clipShape(.capsule)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            isDragging = true
            let pct = max(0, min(1, drag.location.x / geometry.size.width))
            dragValue = pct * duration
          }
          .onEnded { _ in
            isDragging = false
            onSeek(dragValue)
          }
      )
      .animation(.easeOut(duration: 0.12), value: isDragging)
      .frame(height: 8, alignment: .center)
    }
  }

  // MARK: Private

  @State private var isDragging = false
  @State private var dragValue: TimeInterval = 0
}

// MARK: - GlassEffectModifier

private struct GlassEffectModifier: ViewModifier {
  // MARK: Internal

  func body(content: Content) -> some View {
    if #available(macOS 26.0, iOS 26.0, *), isLiquidGlass {
      content
        .glassEffect(.regular, in: .capsule)
        .shadow(radius: 6)
    } else {
      content
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(radius: 6)
    }
  }

  // MARK: Private

  private let isLiquidGlass: Bool = {
    #if compiler(>=6.2) && canImport(AppKit, _version: 26.0)
    if let infoDict = Bundle.main.infoDictionary {
      let verStr = (infoDict["DTPlatformVersion"] as? String)?.prefix(4) ?? "_"
      if let verDouble = Double(verStr) {
        if verDouble < 26 { return false }
        let uiCompat = infoDict["UIDesignRequiresCompatibility"] as? Bool
        if uiCompat == true { return false }
      }
    }
    return true
    #else
    return false
    #endif
  }()
}
