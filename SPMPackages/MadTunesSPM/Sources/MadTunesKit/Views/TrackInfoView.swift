// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TrackInfoView

/// 單一曲目的「取得資訊」視圖，顯示詳盡的 ID3 和音訊格式資訊。
struct TrackInfoView: View {
  // MARK: Internal

  let track: Track
  let detailedMetadata: DetailedTrackMetadata?

  var body: some View {
    NavigationStack {
      List {
        // 基本資訊
        Section("Basic Info") {
          InfoRow(label: "Title", value: track.title)
          InfoRow(label: "Artist", value: track.artist)
          InfoRow(label: "Album", value: track.albumTitle)
          InfoRow(label: "Album Artist", value: track.albumArtist.isEmpty ? "—" : track.albumArtist)
          InfoRow(label: "Track Number", value: track.trackNumber > 0 ? String(track.trackNumber) : "—")
          InfoRow(label: "Disc Number", value: track.discNumber > 0 ? String(track.discNumber) : "—")
          InfoRow(label: "Duration", value: formatDuration(track.duration))
          InfoRow(label: "Genre", value: track.genre.isEmpty ? "—" : track.genre)
          InfoRow(label: "Year", value: track.year.map(String.init) ?? "—")
        }

        // 檔案資訊
        Section("File Info") {
          InfoRow(label: "File Path", value: track.fileURL.path)
          if let fileSize = detailedMetadata?.fileSize {
            InfoRow(label: "File Size", value: formatFileSize(fileSize))
          }
        }

        // 音訊格式資訊
        if let detailed = detailedMetadata {
          Section("Audio Format") {
            InfoRow(label: "Codec", value: detailed.codec ?? "—")
            if let bitDepth = detailed.bitDepth {
              InfoRow(label: "Bit Depth", value: "\(bitDepth)-bit")
            }
            if let sampleRate = detailed.sampleRate {
              InfoRow(label: "Sample Rate", value: formatSampleRate(sampleRate))
            }
            if let channelCount = detailed.channelCount {
              InfoRow(label: "Channels", value: channelCount == 1 ? "Mono" : "\(channelCount)ch")
            }
            if let bitrate = detailed.bitrate {
              InfoRow(label: "Bitrate", value: "\(bitrate / 1000) kbps")
            }
          }
        }
      }
      .navigationTitle("Track Info")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .frame(minWidth: 380, idealWidth: 420, minHeight: 400)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
}

// MARK: - MultiTrackInfoView

/// 多曲目的「取得資訊」視圖，顯示聚合統計資訊。
struct MultiTrackInfoView: View {
  // MARK: Internal

  let tracks: [Track]
  let detailedMetadataList: [DetailedTrackMetadata?]

  var body: some View {
    NavigationStack {
      List {
        // 統計資訊
        Section("Statistics") {
          InfoRow(label: "Tracks", value: "\(tracks.count)")
          InfoRow(label: "Total Duration", value: formatDuration(totalDuration))
          InfoRow(label: "Total File Size", value: totalFileSize.map(formatFileSize) ?? "—")
          InfoRow(label: "Average Track Length", value: formatDuration(averageDuration))

          if let commonAlbum = commonAlbum, !commonAlbum.isEmpty {
            InfoRow(label: "Album", value: commonAlbum)
          }
          if let commonArtist = commonArtist, !commonArtist.isEmpty {
            InfoRow(label: "Artist", value: commonArtist)
          }
          if let commonAlbumArtist = commonAlbumArtist, !commonAlbumArtist.isEmpty {
            InfoRow(label: "Album Artist", value: commonAlbumArtist)
          }
          if let yearRange = yearRange {
            InfoRow(label: "Year Range", value: yearRange)
          }
        }

        // 音訊格式統計
        Section("Audio Formats") {
          ForEach(Array(codecCounts.sorted(by: { $0.value > $1.value })), id: \.key) { codec, count in
            InfoRow(label: codec.isEmpty ? "Unknown" : codec, value: "\(count) tracks")
          }
        }
      }
      .navigationTitle("Multiple Tracks")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .frame(minWidth: 380, idealWidth: 420, minHeight: 300)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  private var totalDuration: TimeInterval {
    tracks.reduce(0) { $0 + $1.duration }
  }

  private var averageDuration: TimeInterval {
    tracks.isEmpty ? 0 : totalDuration / Double(tracks.count)
  }

  private var totalFileSize: Int64? {
    let sizes = detailedMetadataList.compactMap { $0?.fileSize }
    guard !sizes.isEmpty else { return nil }
    return sizes.reduce(0, +)
  }

  private var commonAlbum: String? {
    let albums = Set(tracks.map(\.albumTitle))
    return albums.count == 1 ? tracks.first?.albumTitle : nil
  }

  private var commonArtist: String? {
    let artists = Set(tracks.map(\.artist))
    return artists.count == 1 ? tracks.first?.artist : nil
  }

  private var commonAlbumArtist: String? {
    let albumArtists = Set(tracks.map(\.albumArtist))
    return albumArtists.count == 1 ? tracks.first?.albumArtist : nil
  }

  private var yearRange: String? {
    let years = tracks.compactMap(\.year)
    guard !years.isEmpty else { return nil }
    let minYear = years.min()!
    let maxYear = years.max()!
    return minYear == maxYear ? String(minYear) : "\(minYear) – \(maxYear)"
  }

  private var codecCounts: [String: Int] {
    var counts: [String: Int] = [:]
    for metadata in detailedMetadataList {
      let codec = metadata?.codec ?? "Unknown"
      counts[codec, default: 0] += 1
    }
    return counts
  }
}

// MARK: - InfoRow

private struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    LabeledContent {
      Text(value)
        .textSelection(.enabled)
    } label: {
      Text(label)
    }
  }
}

// MARK: - Helper Functions

private func formatFileSize(_ size: Int64) -> String {
  let formatter = ByteCountFormatter()
  formatter.countStyle = .file
  return formatter.string(fromByteCount: size)
}

private func formatSampleRate(_ rate: Double) -> String {
  if rate >= 1000 {
    let kHz = rate / 1000
    return kHz.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f kHz", kHz)
      : String(format: "%.1f kHz", kHz)
  }
  return String(format: "%.0f Hz", rate)
}
