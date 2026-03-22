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
    Group {
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
    .sheet(isPresented: $isTrackInfoPresented) {
      trackInfoSheetContent
    }
    .alert(
      String(localized: "i18n:Alert.RemoveFromLibraryTitle", bundle: #bundle),
      isPresented: $showDeleteConfirmation
    ) {
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
      Button(String(localized: "i18n:Common.Remove", bundle: #bundle), role: .destructive) {
        if let id = player.currentTrack?.id {
          Task {
            await vm.removeTracksFromLibrary([id])
          }
        }
      }
    } message: {
      let tracksToDeleteCount = 1
      Text("i18n:Alert.RemoveTracksMessage:\(tracksToDeleteCount)", bundle: #bundle)
    }
    .alert(
      String(localized: "i18n:Sidebar.Alert.NewPlaylistTitle", bundle: #bundle),
      isPresented: $showNewPlaylistAlert
    ) {
      TextField(
        String(localized: "i18n:Sidebar.Alert.PlaylistNamePlaceholder", bundle: #bundle),
        text: $newPlaylistName
      )
      Button(String(localized: "i18n:Common.Create", bundle: #bundle)) {
        commitNewPlaylistAlert()
      }
      Button(String(localized: "i18n:Common.Cancel", bundle: #bundle), role: .cancel) {}
    }
  }

  @ViewBuilder var coreComponent: some View {
    HStack(spacing: 16) {
      let artWorkViewHeight: Double = (sansBezel ? 28 : 40) * vm.uiFactor
      ArtworkView(data: artworkData, alwaysGlossy: true)
        .background {
          ZStack {
            Color.gray
            Color.secondary.colorInvert()
          }
        }
        .frame(width: artWorkViewHeight, height: artWorkViewHeight)
        .contentShape(Rectangle())
        .simultaneousGesture(
          TapGesture(count: 2)
            .onEnded { _ in
              guard let track = player.currentTrack else { return }

              if vm.useTableView {
                // Phase 46: When table view is visible, double-clicking the artwork
                // should scroll the table to the currently playing track.
                vm.tableVM.tableScrollTargetID = track.id
                return
              }

              if let album = vm.gridVM.currentAlbumsDisplayed.first(
                where: { $0.allTrackIDsSet.contains(track.id) }
              ) {
                vm.gridVM.scrollToAlbumID = album.id
              } else if vm.isColumnBrowserFiltering || !searchTokens(from: vm.searchText).isEmpty {
                // Album hidden by filters — reset and defer scroll.
                let targetAlbum = vm.library.albums.first(
                  where: { $0.allTrackIDsSet.contains(track.id) }
                )
                guard let targetAlbum else { return }
                vm.resetColumnBrowserFilters()
                vm.searchText = ""
                Task { @MainActor in
                  try? await Task.sleep(for: .milliseconds(150))
                  vm.gridVM.scrollToAlbumID = targetAlbum.id
                }
              }
            }
        )
        .contextMenu {
          // only show menu when a track is active
          if let track = player.currentTrack {
            TrackContextMenu(
              tracks: [track],
              library: vm.library,
              audioPlayer: player,
              currentPlaylistID: vm.selectedPlaylistID,
              isCurrentTrack: true,
              onShowTrackInfo: {
                Task {
                  detailedMetadataForTrack = await MetadataReader.readDetailedMetadata(from: track.fileURL)
                  isTrackInfoPresented = true
                }
              },
              onShowDeleteConfirmation: {
                showDeleteConfirmation = true
              },
              onNewPlaylistWithTracks: { ids in
                trackIDsForNewPlaylist = ids
                newPlaylistName = ""
                showNewPlaylistAlert = true
              }
            )
          }
        }
      VStack(spacing: 0) {
        let mainControlSpacing = 3 * pow(vm.uiFactor, 4)
        EqualSideLayout(centerMode: .fitContent, spacing: mainControlSpacing, verticalAlignment: .center) {
          Color.clear
            .overlay {
              GeometryReader { proxy in
                Color.clear
                  .overlay(alignment: .leading) {
                    nowPlayingInfo
                      .frame(maxWidth: proxy.size.width, alignment: .leading)
                  }
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

          transportControls

          Color.clear
            .overlay {
              GeometryReader { proxy in
                Color.clear
                  .overlay(alignment: .leading) {
                    ViewThatFits {
                      Group {
                        HStack(spacing: mainControlSpacing) {
                          queueToggleButton
                          columnBrowserToggleButton
                          playLoopBehaviorButton
                          volumeControls
                        }
                        .buttonStyle(.plain)
                        .onAppear { miscControlsMovedToToolbar = false }
                        .onDisappear { miscControlsMovedToToolbar = true }
                      }
                      volumeControls
                    }
                    .frame(maxWidth: proxy.size.width, alignment: .trailing)
                  }
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: (sansBezel ? 26 : 34) * vm.uiFactor)
        .toolbar {
          if miscControlsMovedToToolbar {
            ToolbarItem(placement: .confirmationAction) {
              queueToggleButton
            }
            ToolbarItem(placement: .confirmationAction) {
              columnBrowserToggleButton
            }
            ToolbarItem(placement: .confirmationAction) {
              playLoopBehaviorButton
            }
          }
        }
        EqualSideLayout(centerMode: .fillAvailable, spacing: 6, verticalAlignment: .center) {
          Button {
            showRemainingTime.toggle()
          } label: {
            let timeText = showRemainingTime
              ? "-\(formatDuration(max(0, player.duration - player.currentTime)))"
              : formatDuration(player.currentTime)
            Text(timeText)
              .fontWidth(.standard)
              .font(.caption.monospacedDigit())
              .lineLimit(1)
              .frame(height: 6, alignment: .center)
              .fixedSize()
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .contentShape(.rect)

          // Progress scrubber
          ProgressScrubber(
            currentTime: player.currentTime,
            duration: player.duration,
            onSeek: { seekTarget in
              Task {
                await player.seek(to: seekTarget)
              }
            }
          )

          Text(formatDuration(player.duration))
            .fontWidth(.standard)
            .font(.caption.monospacedDigit())
            .frame(height: 6, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
      }
      .frame(width: panelFrameWidth)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(minHeight: 40, alignment: .center)
  }

  // MARK: Private

  @State private var vm: MadTunesViewModel = .shared
  @State private var isColumnBrowserPopoverPresented = false
  @State private var isQueuePopoverPresented = false
  @State private var showRemainingTime = false
  @State private var miscControlsMovedToToolbar = true

  // MARK: track info / playlist & delete state (for context menu on artwork)

  @State private var isTrackInfoPresented = false
  @State private var detailedMetadataForTrack: DetailedTrackMetadata?
  @State private var showDeleteConfirmation = false

  @State private var showNewPlaylistAlert = false
  @State private var newPlaylistName = ""
  @State private var trackIDsForNewPlaylist: Set<UUID> = []

  @State private var player: AudioPlayer

  private var artworkData: Data?
  private var sansBezel = false

  private var useTouchScreenCompact: Bool {
    OS.type != .macOS
      && (vm.screenVM.orientation == .portrait || vm.screenVM.isHorizontallyCompact)
  }

  private var panelFrameWidth: CGFloat {
    let base: CGFloat = 480
    if useTouchScreenCompact {
      return base
    } else {
      return base * vm.uiFactor
    }
  }

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

  // MARK: - Sheet / Alerts

  @ViewBuilder private var trackInfoSheetContent: some View {
    if let track = player.currentTrack {
      TrackInfoView(track: track, detailedMetadata: detailedMetadataForTrack)
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
        .help(accumulated)
      } else {
        Text(String(localized: "i18n:Player.NotPlaying", bundle: #bundle))
          .foregroundStyle(.secondary)
          .font(.callout)
      }
    }
  }

  @ViewBuilder private var transportControls: some View {
    HStack(spacing: 4 * vm.uiFactor) {
      Button { Task { await player.previous() } } label: {
        Image(systemName: "backward.fill")
          .font(.title3)
          .frame(width: 32 * vm.uiFactor, height: 32)
          .contentShape(.rect)
      }
      Button { Task { await player.togglePlayPause() } } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.title)
          .frame(width: 32 * vm.uiFactor, height: 32)
          .contentShape(.rect)
      }
      Button { Task { await player.next() } } label: {
        Image(systemName: "forward.fill")
          .font(.title3)
          .frame(width: 32 * vm.uiFactor, height: 32)
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
      Task {
        switch player.loopBehavior {
        case .sequential: await player.setLoopBehavior(.repeatOne)
        case .repeatOne: await player.setLoopBehavior(.shuffle)
        case .shuffle: await player.setLoopBehavior(.sequential)
        }
      }
    } label: {
      Image(systemName: loopBehaviorIcon)
        .font(.callout)
        .frame(width: 28, height: 28)
        .contentShape(.rect)
        .foregroundStyle(isActive ? Color.madTunesAccent : .secondary)
    }
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
    .popover(isPresented: $isQueuePopoverPresented) {
      PlayingQueueView(player: player)
        .environment(vm)
    }
    .help(String(localized: "i18n:Player.PlayingQueue", bundle: #bundle))
  }

  @ViewBuilder private var volumeControls: some View {
    HStack(spacing: 2) {
      Image(systemName: volumeIcon)
        .font(.caption)
        .frame(width: 28 * vm.uiFactor, height: 28)
      Slider(value: Bindable(player).volume, in: 0 ... 1)
        .frame(width: 60 * vm.uiFactor)
        .controlSize(.mini)
    }
  }

  private func commitNewPlaylistAlert() {
    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    let existingNames = Set(vm.library.playlists.dropFirst(2).map(\.name))
    guard !existingNames.contains(name) else { return }
    vm.library.addPlaylist(name: name)
    if let newPlaylist = vm.library.playlists.last {
      vm.library.addTracks(trackIDsForNewPlaylist, toPlaylist: newPlaylist.id)
    }
    trackIDsForNewPlaylist = []
  }
}

// MARK: - ProgressScrubber

struct ProgressScrubber: View {
  // MARK: Lifecycle

  init(currentTime: TimeInterval, duration: TimeInterval, onSeek: @escaping (TimeInterval) -> Void) {
    self.currentTime = currentTime
    self.duration = duration
    self.onSeek = onSeek
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

// MARK: - EqualSideLayout

/// HStack { [A][B][C] }
/// 在 B 使用 fixedSize (width) 或滿版的情况下让 A 与 C 的可用空间等分。
private struct EqualSideLayout: Layout {
  // MARK: Lifecycle

  init(
    centerMode: CenterMode,
    spacing: CGFloat = 0,
    verticalAlignment: VerticalAlignment = .center
  ) {
    self.centerMode = centerMode
    self.spacing = spacing
    self.verticalAlignment = verticalAlignment
  }

  // MARK: Internal

  enum CenterMode {
    case fitContent
    case fillAvailable
  }

  struct CachedLayout {
    var sideWidth: CGFloat
    var bWidth: CGFloat
    var height: CGFloat
    var contentWidth: CGFloat
  }

  func makeCache(subviews: Subviews) -> CachedLayout? {
    nil
  }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CachedLayout?
  )
    -> CGSize {
    guard subviews.count == 3 else { return .zero }

    let totalSpacing = spacing * CGFloat(subviews.count - 1)

    // ✅ 改成：如果没有明确宽度，就走 intrinsic
    guard let totalWidth = proposal.width else {
      return intrinsicSize(subviews, totalSpacing)
    }

    let contentWidth = max(0, totalWidth - totalSpacing)

    let layout = compute(contentWidth: contentWidth, subviews: subviews)
    cache = CachedLayout(
      sideWidth: layout.sideWidth,
      bWidth: layout.bWidth,
      height: layout.height,
      contentWidth: contentWidth
    )

    return CGSize(width: totalWidth, height: layout.height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CachedLayout?
  ) {
    guard subviews.count == 3 else { return }

    let totalSpacing = spacing * CGFloat(subviews.count - 1)
    let contentWidth = max(0, bounds.width - totalSpacing)

    let layout: (sideWidth: CGFloat, bWidth: CGFloat, height: CGFloat)
    if let cached = cache, cached.contentWidth == contentWidth {
      layout = (cached.sideWidth, cached.bWidth, cached.height)
    } else {
      layout = compute(contentWidth: contentWidth, subviews: subviews)
    }

    func yOffset(for size: CGSize) -> CGFloat {
      switch verticalAlignment {
      case .top:
        return bounds.minY
      case .center:
        return bounds.minY + (bounds.height - size.height) / 2
      case .bottom:
        return bounds.maxY - size.height
      default:
        return bounds.minY + (bounds.height - size.height) / 2
      }
    }

    var x = bounds.minX

    // A
    let aSize = subviews[0].sizeThatFits(.init(width: layout.sideWidth, height: bounds.height))
    subviews[0].place(
      at: CGPoint(x: x, y: yOffset(for: aSize)),
      proposal: .init(width: layout.sideWidth, height: aSize.height)
    )

    x += layout.sideWidth + spacing

    // B
    let bSize = subviews[1].sizeThatFits(.init(width: layout.bWidth, height: bounds.height))
    subviews[1].place(
      at: CGPoint(x: x, y: yOffset(for: bSize)),
      proposal: .init(width: layout.bWidth, height: bSize.height)
    )

    x += layout.bWidth + spacing

    // C
    let cSize = subviews[2].sizeThatFits(.init(width: layout.sideWidth, height: bounds.height))
    subviews[2].place(
      at: CGPoint(x: x, y: yOffset(for: cSize)),
      proposal: .init(width: layout.sideWidth, height: cSize.height)
    )
  }

  // MARK: Private

  private let centerMode: CenterMode
  private let spacing: CGFloat
  private let verticalAlignment: VerticalAlignment

  private func compute(
    contentWidth: CGFloat,
    subviews: Subviews
  )
    -> (sideWidth: CGFloat, bWidth: CGFloat, height: CGFloat) {
    let bIntrinsic = subviews[1].sizeThatFits(.unspecified)

    // Allow the left/right sides to size themselves, and only shrink the center
    // content when space is constrained.
    let leftIntrinsic = subviews[0].sizeThatFits(.unspecified)
    let rightIntrinsic = subviews[2].sizeThatFits(.unspecified)
    let minSideWidth = max(leftIntrinsic.width, rightIntrinsic.width)

    let sideWidth: CGFloat
    let bWidth: CGFloat

    switch centerMode {
    case .fitContent:
      // Give the center the room it wants first, but ensure left/right views
      // are never squeezed below their intrinsic width unless the total width is
      // smaller than the sum of their intrinsic widths.
      let desiredSideWidth = minSideWidth
      let maxCenterWidth = max(0, contentWidth - 2 * desiredSideWidth)

      let centerWidth = min(bIntrinsic.width, maxCenterWidth)
      let remaining = contentWidth - centerWidth

      // If we have enough room, expand sides evenly. Otherwise, shrink the
      // center to keep the side views at (or near) their intrinsic widths.
      let sideIfExpanded = remaining / 2
      if sideIfExpanded >= desiredSideWidth {
        sideWidth = sideIfExpanded
        bWidth = centerWidth
      } else {
        let clampedSide = min(desiredSideWidth, contentWidth / 2)
        sideWidth = clampedSide
        bWidth = max(0, contentWidth - 2 * clampedSide)
      }

    case .fillAvailable:
      let aMin = leftIntrinsic.width
      let cMin = rightIntrinsic.width

      let safeRemaining = max(0, contentWidth - aMin - cMin)

      bWidth = safeRemaining
      sideWidth = (contentWidth - bWidth) / 2
    }

    let aSize = subviews[0].sizeThatFits(.init(width: sideWidth, height: nil))
    let cSize = subviews[2].sizeThatFits(.init(width: sideWidth, height: nil))

    let height = max(aSize.height, bIntrinsic.height, cSize.height)

    return (sideWidth, bWidth, height)
  }

  private func intrinsicSize(_ subviews: Subviews, _ totalSpacing: CGFloat) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

    let width = sizes.map(\.width).reduce(0, +) + totalSpacing
    let height = sizes.map(\.height).max() ?? 0

    return CGSize(width: width, height: height)
  }
}

// MARK: - GlassEffectModifier

private struct GlassEffectModifier: ViewModifier {
  func body(content: Content) -> some View {
    Group {
      if #available(macOS 26.0, iOS 26.0, *), OS.liquidGlassThemeSuspected {
        content
          .background {
            GlassyAlbumOverlay().opacity(0.1)
          }
          .clipShape(.capsule)
          .glassEffect(.regular, in: .capsule)
          .shadow(radius: 2)
      } else {
        content
          .background {
            GlassyAlbumOverlay().opacity(0.1)
          }
          .background(.ultraThinMaterial)
          .clipShape(.capsule)
          .shadow(radius: 2)
      }
    }
  }
}
