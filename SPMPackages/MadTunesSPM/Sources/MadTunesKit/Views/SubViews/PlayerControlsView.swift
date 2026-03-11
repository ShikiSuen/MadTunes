// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
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
        HStack(spacing: 16) {
          // Now-playing info (left)
          nowPlayingInfo
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: 4) {
            columnBrowserToggleButton
            transportControls
            queueToggleButton
          }

          HStack(spacing: 4) {
            playLoopBehaviorButton
            volumeControls
          }
          .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: sansBezel ? 26 : 34)
        HStack {
          Button {
            showRemainingTime.toggle()
          } label: {
            let timeText = showRemainingTime
              ? "-\(formatDuration(max(0, player.duration - player.currentTime)))"
              : formatDuration(player.currentTime)
            Text(timeText)
              .fontWidth(.standard)
              .font(.caption.monospacedDigit())
              .frame(height: 6, alignment: .center)
          }
          .buttonStyle(.plain)
          scrubber
          Text(formatDuration(player.duration))
            .fontWidth(.standard)
            .font(.caption.monospacedDigit())
            .frame(height: 6, alignment: .center)
        }
        .frame(minWidth: 500)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(minHeight: 40, alignment: .center)
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared
  @State private var isColumnBrowserPopoverPresented = false
  @State private var isQueuePopoverPresented = false
  @State private var showRemainingTime = false

  private var volumeIcon: String {
    if player.volume <= 0 { return "speaker.slash.fill" }
    if player.volume < 0.33 { return "speaker.wave.1.fill" }
    if player.volume < 0.66 { return "speaker.wave.2.fill" }
    return "speaker.wave.3.fill"
  }

  private var loopBehaviorIcon: String {
    switch player.loopBehavior {
    case .sequential: "repeat"
    case .repeatOne: "repeat.1"
    case .shuffle: "shuffle"
    }
  }

  private var loopBehaviorTooltip: String {
    switch player.loopBehavior {
    case .sequential: String(localized: "i18n:Player.LoopSequential", bundle: #bundle)
    case .repeatOne: String(localized: "i18n:Player.LoopRepeatOne", bundle: #bundle)
    case .shuffle: String(localized: "i18n:Player.LoopShuffle", bundle: #bundle)
    }
  }

  // MARK: - Subviews

  @ViewBuilder private var nowPlayingInfo: some View {
    HStack(spacing: 10) {
      if let track = player.currentTrack {
        let accumulated = "\(track.title)\n\n→ \(track.artist)"
        VStack(alignment: .leading, spacing: 1) {
          Text(track.title)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(1)
            .truncationMode(.tail)
          Text(track.artist)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .contentShape(.rect)
        .frame(maxWidth: 200, alignment: .leading)
        .help(accumulated)
      } else {
        Text(String(localized: "i18n:Player.NotPlaying", bundle: #bundle))
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
    .frame(maxHeight: sansBezel ? 15 : 35)
  }

  @ViewBuilder private var playLoopBehaviorButton: some View {
    let isActive = player.loopBehavior != .sequential
    Button {
      switch player.loopBehavior {
      case .sequential: player.loopBehavior = .repeatOne
      case .repeatOne: player.loopBehavior = .shuffle
      case .shuffle: player.loopBehavior = .sequential
      }
    } label: {
      Image(systemName: loopBehaviorIcon)
        .font(.callout)
        .frame(width: 28, height: 28)
        .contentShape(.rect)
        .foregroundStyle(isActive ? Color.madTunesAccent : .secondary)
    }
    .buttonStyle(.plain)
    .help(loopBehaviorTooltip)
  }

  @ViewBuilder private var columnBrowserToggleButton: some View {
    let isFiltering = vm.isColumnBrowserFiltering
    let iconName = (isFiltering || isColumnBrowserPopoverPresented)
      ? "line.3.horizontal.decrease.circle.fill"
      : "line.3.horizontal.decrease.circle"
    let iconColor: Color = isColumnBrowserPopoverPresented
      ? .primary
      : (isFiltering ? .red : .secondary)
    Button {
      isColumnBrowserPopoverPresented.toggle()
    } label: {
      Image(systemName: iconName)
        .font(.callout)
        .frame(width: 28, height: 28)
        .contentShape(.rect)
        .foregroundStyle(iconColor)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $isColumnBrowserPopoverPresented) {
      ColumnBrowserView()
    }
    .help(String(localized: "i18n:ColumnBrowser.Title", bundle: #bundle))
  }

  @ViewBuilder private var queueToggleButton: some View {
    Button {
      isQueuePopoverPresented.toggle()
    } label: {
      Image(systemName: "list.bullet")
        .font(.callout)
        .frame(width: 28, height: 28)
        .contentShape(.rect)
        .foregroundStyle(isQueuePopoverPresented ? Color.madTunesAccent : .secondary)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $isQueuePopoverPresented) {
      PlayingQueueView(player: player)
    }
    .help(String(localized: "i18n:Player.PlayingQueue", bundle: #bundle))
  }

  @ViewBuilder private var volumeControls: some View {
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
    if #available(macOS 26, iOS 26, macCatalyst 26, *) {
      if let infoDict = Bundle.main.infoDictionary {
        let verStr = (infoDict["DTPlatformVersion"] as? String)?.prefix(4) ?? "_"
        if let verDouble = Double(verStr) {
          if verDouble < 26 { return false }
          let uiCompat = infoDict["UIDesignRequiresCompatibility"] as? Bool
          if uiCompat == true { return false }
        }
      }
      return true
    } else {
      return false
    }
  }()
}
