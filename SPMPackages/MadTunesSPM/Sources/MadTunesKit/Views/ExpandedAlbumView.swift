// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - ExpandedAlbumView

/// The detail pane shown when an album is expanded in the grid.
/// Displays album art on the left, track listing on the right.
struct ExpandedAlbumView: View {
  // MARK: Internal

  let album: Album
  var currentTrackID: UUID?
  let containerWidth: CGFloat
  @Binding var selectedTrackIDs: Set<UUID>
  let onTrackSelected: (Track, [Track]) -> Void
  let onClose: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 20) {
      // Track listing
      VStack(alignment: .leading, spacing: 0) {
        header
        trackList
        songCountAndLengthView
          .padding(.top, 8)
      }

      // Large album artwork
      VStack {
        LazyAlbumArtworkView(album: album)
          .frame(width: 200, height: 200)
      }
      .fixedSize()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(.secondary.opacity(0.1))
    )
    .padding(.horizontal, 4)
  }

  // MARK: Private

  @State private var lastClickedTrackID: UUID?

  /// Track list width computed deterministically from the parent container width.
  /// Subtracts: LazyVStack padding (2×16=32), .padding(.horizontal,4) (2×4=8),
  /// inner .padding(16) (2×16=32), artwork (200), HStack spacing (20).
  private var trackListWidth: CGFloat {
    max(300, containerWidth - 292)
  }

  // MARK: - Subviews

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(album.title)
          .font(.title2)
          .fontWeight(.bold)
        Text(album.artist)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      // Play-all badge
      Button {
        let sorted = album.sortedTracks
        if let first = sorted.first {
          onTrackSelected(first, sorted)
        }
      } label: {
        Image(systemName: "play.circle.fill")
          .font(.title)
          .symbolRenderingMode(.hierarchical)
      }
      .buttonStyle(.plain)

      Button(action: onClose) {
        Image(systemName: "xmark.circle.fill")
          .font(.title2)
          .symbolRenderingMode(.hierarchical)
      }
      .buttonStyle(.plain)
    }
    .padding(.bottom, 8)
  }

  @ViewBuilder private var trackList: some View {
    let sorted = album.sortedTracks
    let hideArtist = album.allTrackArtistsSameAsAlbumArtist
    let showDisc = album.showDiscNumber
    let maxRowsPerColumn = 7

    let columnCount = trackListColumnCount(
      trackCount: sorted.count,
      availableWidth: trackListWidth,
      maxRowsPerColumn: maxRowsPerColumn
    )
    let useSingleColumn = columnCount == 1
    let itemsPerColumn = Int(ceil(Double(sorted.count) / Double(columnCount)))
    let columns: [[Track]] = stride(from: 0, to: sorted.count, by: itemsPerColumn).map {
      Array(sorted[$0 ..< min($0 + itemsPerColumn, sorted.count)])
    }

    HStack(alignment: .top, spacing: 6) {
      ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
        VStack(spacing: 0) {
          ForEach(Array(column.enumerated()), id: \.offset) { offset, track in
            VStack(spacing: 0) {
              if offset == 0 {
                songDividerInList
              }
              TrackRow(
                track: track,
                hideArtist: hideArtist,
                showDiscNumber: showDisc,
                isPlaying: track.id == currentTrackID,
                isSelected: selectedTrackIDs.contains(track.id)
              )
              .contentShape(Rectangle())
              .onTapGesture(count: 2) {
                Task { @MainActor in
                  handleTrackSelection(track, in: sorted)
                }
                Task { @MainActor in
                  onTrackSelected(track, sorted)
                }
              }
              .onTapGesture(count: 1) {
                Task { @MainActor in
                  handleTrackSelection(track, in: sorted)
                }
              }
              songDividerInList
            }
          }
        }
        // 僅單欄時，最大欄寬 500px。
        .frame(
          maxWidth: useSingleColumn ? 500 : .infinity,
          alignment: .leading
        )
      }
      if useSingleColumn {
        Spacer()
      }
    }
  }

  @ViewBuilder private var songCountAndLengthView: some View {
    HStack {
      Text("\(album.tracks.count) songs")
      Spacer()
      Text(formatDuration(album.totalDuration))
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  @ViewBuilder private var songDividerInList: some View {
    LinearGradient(
      colors: [
        Color.clear,
        Color.primary.opacity(0.2),
        Color.primary.opacity(0.1),
        Color.primary.opacity(0.05),
        Color.clear,
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
    .frame(height: 1)
  }

  private func trackListColumnCount(
    trackCount: Int, availableWidth: CGFloat, maxRowsPerColumn: Int
  )
    -> Int {
    let minColumnWidth: CGFloat = 300
    let maxPossibleColumns = max(1, Int(availableWidth / minColumnWidth))
    let desiredColumns = trackCount > maxRowsPerColumn ? maxPossibleColumns : 1
    return max(1, min(trackCount, desiredColumns))
  }

  private func handleTrackSelection(_ track: Track, in sortedTracks: [Track]) {
    #if canImport(AppKit) && !canImport(UIKit)
    let modifiers = NSEvent.modifierFlags
    if modifiers.contains(.command) {
      if selectedTrackIDs.contains(track.id) {
        selectedTrackIDs.remove(track.id)
      } else {
        selectedTrackIDs.insert(track.id)
      }
    } else if modifiers.contains(.shift),
              let lastID = lastClickedTrackID,
              let lastIdx = sortedTracks.firstIndex(where: { $0.id == lastID }),
              let curIdx = sortedTracks.firstIndex(where: { $0.id == track.id }) {
      let range = min(lastIdx, curIdx) ... max(lastIdx, curIdx)
      for i in range {
        selectedTrackIDs.insert(sortedTracks[i].id)
      }
    } else {
      selectedTrackIDs = [track.id]
    }
    #else
    selectedTrackIDs = [track.id]
    #endif
    lastClickedTrackID = track.id
  }
}

// MARK: - TrackRow

struct TrackRow: View {
  // MARK: Internal

  let track: Track
  var hideArtist: Bool = false
  var showDiscNumber: Bool = false
  var isPlaying: Bool = false
  var isSelected: Bool = false

  var body: some View {
    HStack(spacing: 8) {
      if isPlaying {
        Image(systemName: "speaker.wave.2.fill")
          .frame(width: 32, alignment: .trailing)
          .foregroundStyle(Color.madTunesAccent)
          .font(.caption)
      } else {
        Text(trackNumberLabel)
          .frame(width: 32, alignment: .trailing)
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
        .frame(width: 52, alignment: .trailing)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
    .background(
      RoundedRectangle(cornerRadius: 4).fill(trackRowBackground)
    )
    .onHover { hovered in
      Task { @MainActor in
        isHovered = hovered
      }
    }
  }

  // MARK: Private

  @State private var isHovered: Bool = false

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
