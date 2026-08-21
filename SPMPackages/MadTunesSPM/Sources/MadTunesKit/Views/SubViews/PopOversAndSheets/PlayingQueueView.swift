// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PlayingQueueView

/// Popover content displaying the current playback queue.
/// Supports drag-to-reorder and highlights the currently-playing track.
struct PlayingQueueView: View {
  // MARK: Lifecycle

  init(player: AudioPlayer) {
    self.player = player
  }

  // MARK: Internal

  var body: some View {
    VStack(spacing: 0) {
      // Header with controls
      HStack {
        Text(String(localized: "i18n:Queue.Header", bundle: #bundle))
          .font(.headline)
        Spacer()
        Button {
          Task { await player.clearQueueKeepingCurrentTrack() }
        } label: {
          Image(systemName: "trash")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .disabled(!canClearQueueExceptCurrent)
        .opacity(canClearQueueExceptCurrent ? 1 : 0.4)
        .help(String(localized: "i18n:Queue.ClearExceptCurrent", bundle: #bundle))
        Button {
          scrambleQueue()
        } label: {
          Image(systemName: "shuffle")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .help(String(localized: "i18n:Queue.ScrambleHelp", bundle: #bundle))
        Text("i18n:Unit:Track:\(player.queue.count)", bundle: #bundle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 20 * vm.uiFactor)
      .padding(.vertical, 8 * vm.uiFactor)

      Divider()

      if player.queue.isEmpty {
        ContentUnavailableView {
          Label(String(localized: "i18n:Queue.Empty", bundle: #bundle), systemImage: "music.note.list")
        } description: {
          Text(String(localized: "i18n:Queue.EmptyDescription", bundle: #bundle))
        }
        .frame(minHeight: 200 * vm.uiFactor)
      } else {
        List(selection: $highlightedIndex) {
          ForEach(Array(player.queue.enumerated()), id: \.offset) { index, track in
            PlayingQueueRow(
              index: index,
              track: track,
              queueCount: player.queue.count,
              isCurrent: index == player.currentIndex,
              isHighlighted: index == highlightedIndex,
              artworkData: queueArtworkCache[vm.library.albumKey(title: track.albumTitle, artist: track.albumArtist)],
              onRemove: { removeFromQueue(at: index) },
              onMoveUp: { moveQueueItem(from: index, to: index - 1) },
              onMoveDown: { moveQueueItem(from: index, to: index + 2) }
            )
            .task(id: track.id) {
              let key = vm.library.albumKey(title: track.albumTitle, artist: track.albumArtist)
              guard queueArtworkCache[key] == nil else { return }
              let result = await vm.library.loadArtwork(
                forAlbumKey: key,
                sampleTrackURL: track.fileURL,
                sampleTrackBookmark: track.bookmarkData
              )
              if let data = result?.data, let image = ArtworkView.makeImage(from: data) {
                queueArtworkCache[key] = image
              }
            }
            .listRowBackground(
              rowBackground(for: index)
            )
            .contentShape(.rect)
            .onTapGesture {
              highlightedIndex = index
              Task { await player.setQueue(player.queue, startingAt: index) }
            }
            .tag(index)
          }
          .onMove { source, destination in
            Task { await player.moveQueueItem(from: source, to: destination) }
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onKeyPress { press in
          handleKeyPress(press)
        }
        .onChange(of: player.currentIndex) { _, newIndex in
          highlightedIndex = newIndex
        }
        .onAppear {
          highlightedIndex = player.currentIndex
        }
      }
    }
    .frame(width: 460 * vm.uiFactor, height: dynamicHeight)
  }

  // MARK: Private

  @State private var player: AudioPlayer

  @Environment(MadTunesViewModel.self) private var vm
  @State private var highlightedIndex: Int?
  /// Phase 108: Per-popover artwork cache (non-observable, no cascade).
  /// Phase 112: Store decoded Image instead of raw Data to avoid JPEG re-decode.
  @State private var queueArtworkCache: [String: Image] = [:]

  private var dynamicHeight: CGFloat? {
    guard !player.queue.isEmpty else { return nil }
    return min(CGFloat(player.queue.count) * 56 * vm.uiFactor + 60 * vm.uiFactor, 460 * vm.uiFactor)
  }

  /// Phase 178: Whether the "clear except current" action can remove anything.
  private var canClearQueueExceptCurrent: Bool {
    guard !player.queue.isEmpty else { return false }
    guard let current = player.currentTrack else { return true }
    return player.queue.contains { $0.id != current.id }
  }

  private func rowBackground(for index: Int) -> some View {
    if index == highlightedIndex, index == player.currentIndex {
      return Color.madTunesAccent.opacity(0.3)
    } else if index == highlightedIndex {
      return Color.secondary.opacity(0.15)
    } else if index == player.currentIndex {
      return Color.madTunesAccent.opacity(0.15)
    } else {
      return Color.clear
    }
  }

  private func removeFromQueue(at index: Int) {
    guard player.queue.indices.contains(index) else { return }
    var newQueue = player.queue
    newQueue.remove(at: index)
    if newQueue.isEmpty {
      Task { await player.stop() }
    } else {
      // Adjust current index if needed
      let newIndex = min(player.currentIndex, newQueue.count - 1)
      Task { await player.setQueue(newQueue, startingAt: newIndex) }
    }
  }

  private func moveQueueItem(from: Int, to: Int) {
    guard from != to,
          player.queue.indices.contains(from),
          to >= 0, to <= player.queue.count else { return }
    let source = IndexSet([from])
    Task { await player.moveQueueItem(from: source, to: to) }
  }

  private func scrambleQueue() {
    guard !player.queue.isEmpty else { return }
    var shuffled = player.queue
    shuffled.shuffle()
    let currentTrack = player.currentTrack
    let newIndex = currentTrack.flatMap { track in
      shuffled.firstIndex(where: { $0.id == track.id })
    } ?? 0
    Task { await player.setQueue(shuffled, startingAt: newIndex) }
  }

  // MARK: - Keyboard Handling

  private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
    switch press.key {
    case .upArrow:
      return moveHighlight(up: true)
    case .downArrow:
      return moveHighlight(up: false)
    case .delete, .deleteForward:
      return removeHighlightedTrack()
    default:
      return .ignored
    }
  }

  private func moveHighlight(up: Bool) -> KeyPress.Result {
    guard !player.queue.isEmpty else { return .ignored }

    let currentIdx = highlightedIndex ?? player.currentIndex
    let newIndex: Int

    if up {
      newIndex = max(0, currentIdx - 1)
    } else {
      newIndex = min(player.queue.count - 1, currentIdx + 1)
    }

    guard newIndex != currentIdx else { return .handled }

    highlightedIndex = newIndex
    Task { await player.setQueue(player.queue, startingAt: newIndex) }
    return .handled
  }

  private func removeHighlightedTrack() -> KeyPress.Result {
    guard let indexToRemove = highlightedIndex,
          player.queue.indices.contains(indexToRemove)
    else {
      return .ignored
    }

    // Now remove the highlighted track
    removeFromQueue(at: indexToRemove)

    return .handled
  }
}

// MARK: - PlayingQueueRow

struct PlayingQueueRow: View {
  // MARK: Lifecycle

  init(
    index: Int,
    track: Track,
    queueCount: Int,
    isCurrent: Bool,
    isHighlighted: Bool,
    artworkData: Image?,
    onRemove: @escaping () -> Void,
    onMoveUp: @escaping () -> Void,
    onMoveDown: @escaping () -> Void
  ) {
    self.index = index
    self.track = track
    self.queueCount = queueCount
    self.isCurrent = isCurrent
    self.isHighlighted = isHighlighted
    self.artworkData = artworkData
    self.onRemove = onRemove
    self.onMoveUp = onMoveUp
    self.onMoveDown = onMoveDown
  }

  // MARK: Internal

  let index: Int
  let track: Track
  let queueCount: Int
  let isCurrent: Bool
  let isHighlighted: Bool
  let artworkData: Image?
  let onRemove: () -> Void
  let onMoveUp: () -> Void
  let onMoveDown: () -> Void

  var body: some View {
    HStack(spacing: 10 * ThisDevice.uiFactor) {
      ArtworkView(image: artworkData, alwaysGlossy: true)
        .frame(width: 36 * ThisDevice.uiFactor, height: 36 * ThisDevice.uiFactor)

      VStack(alignment: .leading, spacing: 1 * ThisDevice.uiFactor) {
        Text(track.title)
          .font(.callout)
          .fontWeight(isCurrent ? .semibold : .regular)
          .lineLimit(1)
        HStack(spacing: 4 * ThisDevice.uiFactor) {
          Text(track.artist)
          Text(verbatim: "·")
          Text(track.albumTitle)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer(minLength: 0)

      Text(formatDuration(track.duration))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)

      HStack(spacing: 4 * ThisDevice.uiFactor) {
        Button {
          onMoveUp()
        } label: {
          Image(systemName: "arrow.up")
            .font(.caption2)
            .frame(width: 20 * ThisDevice.uiFactor, height: 20 * ThisDevice.uiFactor)
        }
        .buttonStyle(.plain)
        .help(String(localized: "i18n:Queue.MoveUp", bundle: #bundle))
        .opacity(index > 0 ? 1 : 0.3)
        .disabled(index <= 0)

        Button {
          onMoveDown()
        } label: {
          Image(systemName: "arrow.down")
            .font(.caption2)
            .frame(width: 20 * ThisDevice.uiFactor, height: 20 * ThisDevice.uiFactor)
        }
        .buttonStyle(.plain)
        .help(String(localized: "i18n:Queue.MoveDown", bundle: #bundle))
        .opacity(index < queueCount - 1 ? 1 : 0.3)
        .disabled(index >= queueCount - 1)

        Button {
          onRemove()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.caption2)
            .frame(width: 20 * ThisDevice.uiFactor, height: 20 * ThisDevice.uiFactor)
            .foregroundStyle(.red.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help(String(localized: "i18n:Queue.RemoveFromQueue", bundle: #bundle))
      }
    }
    .padding(.vertical, 2 * ThisDevice.uiFactor)
  }
}
