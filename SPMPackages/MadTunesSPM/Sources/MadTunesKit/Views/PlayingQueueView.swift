// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PlayingQueueView

/// Popover content displaying the current playback queue.
/// Supports drag-to-reorder and highlights the currently-playing track.
struct PlayingQueueView: View {
  // MARK: Internal

  var player: AudioPlayer

  var body: some View {
    VStack(spacing: 0) {
      // Header with controls
      HStack {
        Text("Playing Queue")
          .font(.headline)
        Spacer()
        Button {
          scrambleQueue()
        } label: {
          Image(systemName: "shuffle")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Scramble queue order")
        Text("\(player.queue.count) tracks")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      if player.queue.isEmpty {
        ContentUnavailableView {
          Label("Queue Empty", systemImage: "music.note.list")
        } description: {
          Text("Play an album or track to populate the queue.")
        }
        .frame(minHeight: 200)
      } else {
        List {
          ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
            PlayingQueueRow(
              index: index,
              track: track,
              queueCount: player.queue.count,
              isCurrent: index == player.currentIndex,
              artworkData: artworkData(for: track),
              onRemove: { removeFromQueue(at: index) },
              onMoveUp: { moveQueueItem(from: index, to: index - 1) },
              onMoveDown: { moveQueueItem(from: index, to: index + 2) }
            )
            .listRowBackground(
              index == player.currentIndex
                ? Color.madTunesAccent.opacity(0.15)
                : Color.clear
            )
            .contentShape(.rect)
            .onTapGesture {
              player.setQueue(player.queue, startingAt: index)
            }
          }
          .onMove { source, destination in
            player.moveQueueItem(from: source, to: destination)
          }
        }
        .listStyle(.plain)
        #if !os(macOS)
          .environment(\.editMode, .constant(.active))
        #endif
      }
    }
    .frame(width: 380, height: min(CGFloat(player.queue.count) * 56 + 60, 460))
  }

  // MARK: Private

  @Environment(MadTunesViewModel.self) private var viewModel

  private func artworkData(for track: Track) -> Data? {
    let key = viewModel.library.albumKey(title: track.albumTitle, artist: track.albumArtist)
    return viewModel.library.artworkCache[key]
  }

  private func removeFromQueue(at index: Int) {
    guard player.queue.indices.contains(index) else { return }
    var newQueue = player.queue
    newQueue.remove(at: index)
    if newQueue.isEmpty {
      player.stop()
    } else {
      // Adjust current index if needed
      let newIndex = min(player.currentIndex, newQueue.count - 1)
      player.setQueue(newQueue, startingAt: newIndex)
    }
  }

  private func moveQueueItem(from: Int, to: Int) {
    guard from != to,
          player.queue.indices.contains(from),
          to >= 0, to <= player.queue.count else { return }
    let source = IndexSet([from])
    player.moveQueueItem(from: source, to: to)
  }

  private func scrambleQueue() {
    guard !player.queue.isEmpty else { return }
    var shuffled = player.queue
    shuffled.shuffle()
    let currentTrack = player.currentTrack
    let newIndex = currentTrack.flatMap { track in
      shuffled.firstIndex(where: { $0.id == track.id })
    } ?? 0
    player.setQueue(shuffled, startingAt: newIndex)
  }
}

// MARK: - PlayingQueueRow

struct PlayingQueueRow: View {
  let index: Int
  let track: Track
  let queueCount: Int
  let isCurrent: Bool
  let artworkData: Data?
  let onRemove: () -> Void
  let onMoveUp: () -> Void
  let onMoveDown: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      ArtworkView(data: artworkData)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 1) {
        Text(track.title)
          .font(.callout)
          .fontWeight(isCurrent ? .semibold : .regular)
          .lineLimit(1)
        HStack(spacing: 4) {
          Text(track.artist)
          Text("·")
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

      HStack(spacing: 4) {
        Button {
          onMoveUp()
        } label: {
          Image(systemName: "arrow.up")
            .font(.caption2)
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .help("Move up")
        .opacity(index > 0 ? 1 : 0.3)
        .disabled(index <= 0)

        Button {
          onMoveDown()
        } label: {
          Image(systemName: "arrow.down")
            .font(.caption2)
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .help("Move down")
        .opacity(index < queueCount - 1 ? 1 : 0.3)
        .disabled(index >= queueCount - 1)

        Button {
          onRemove()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.caption2)
            .frame(width: 20, height: 20)
            .foregroundStyle(.red.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help("Remove from queue")
      }
    }
    .padding(.vertical, 2)
  }
}
