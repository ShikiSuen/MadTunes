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
      ArtworkView(data: artworkData, alwaysGlossy: true)
        .frame(width: artWorkViewHeight, height: artWorkViewHeight)
        .contentShape(Rectangle())
        .simultaneousGesture(
          TapGesture(count: 2)
            .onEnded { _ in
              guard let track = player.currentTrack else { return }
              if let album = vm.currentAlbums.first(
                where: { $0.allTrackIDsSet.contains(track.id) }
              ) {
                vm.scrollToAlbumID = album.id
              } else if vm.isColumnBrowserFiltering || !vm.searchText.isEmpty {
                // Album hidden by filters — reset and defer scroll.
                let targetAlbum = vm.library.albums.first(
                  where: { $0.allTrackIDsSet.contains(track.id) }
                )
                guard let targetAlbum else { return }
                vm.resetColumnBrowserFilters()
                vm.searchText = ""
                Task { @MainActor in
                  try? await Task.sleep(for: .milliseconds(150))
                  vm.scrollToAlbumID = targetAlbum.id
                }
              }
            }
        )
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
            transportControls
            queueToggleButton
            columnBrowserToggleButton
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
        .frame(maxWidth: .infinity)
      }
      .frame(width: 480)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(minHeight: 40, alignment: .center)
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared
  @State private var isColumnBrowserPopoverPresented = false
  @State private var isQueuePopoverPresented = false
  @State private var showRemainingTime = false

  private var player: AudioPlayer
  private var artworkData: Data?
  private var sansBezel = false

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
        .frame(maxWidth: .infinity, alignment: .leading)
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
      case .sequential: player.setLoopBehavior(.repeatOne)
      case .repeatOne: player.setLoopBehavior(.shuffle)
      case .shuffle: player.setLoopBehavior(.sequential)
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
        .frame(width: 28, height: 28)

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
  // MARK: Lifecycle

  init(currentTime: TimeInterval, duration: TimeInterval, onSeek: @escaping (TimeInterval) -> Void) {
    self.currentTime = currentTime
    self.duration = duration
    self.onSeek = onSeek
    self.isDragging = isDragging
    self.dragValue = dragValue
  }

  // MARK: Internal

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

  private let currentTime: TimeInterval
  private let duration: TimeInterval
  private let onSeek: (TimeInterval) -> Void
}

// MARK: - GlassEffectModifier

private struct GlassEffectModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 26.0, iOS 26.0, *), OS.liquidGlassThemeSuspected {
      content
        .glassEffect(.regular, in: .capsule)
        .shadow(radius: 2)
    } else {
      content
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(radius: 2)
    }
  }
}
