// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - TrackInfoView

/// 單一曲目的「取得資訊」視圖，顯示詳盡的 ID3 和音訊格式資訊。
struct TrackInfoView: View {
  // MARK: Lifecycle

  init(
    track: Track,
    detailedMetadata: DetailedTrackMetadata?
  ) {
    self.track = track
    self.detailedMetadata = detailedMetadata
  }

  // MARK: Internal

  var body: some View {
    NavigationStack {
      List {
        // 基本資訊
        Section(String(localized: "i18n:TrackInfo.Sections.BasicInfo", bundle: #bundle)) {
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Title", bundle: #bundle),
            value: Text(verbatim: track.title),
            isFallback: track.fallbackFields.contains(.title)
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Artist", bundle: #bundle),
            value: Text(verbatim: track.artist),
            isFallback: track.fallbackFields.contains(.artist)
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Album", bundle: #bundle),
            value: Text(verbatim: track.albumTitle),
            isFallback: track.fallbackFields.contains(.albumTitle)
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.AlbumArtist", bundle: #bundle),
            value: Text(verbatim: track.albumArtist.isEmpty ? "—" : track.albumArtist),
            isFallback: track.fallbackFields.contains(.albumArtist)
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.TrackNumber", bundle: #bundle),
            value: Text(verbatim: track.trackNumber > 0 ? String(track.trackNumber) : "—")
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.DiscNumber", bundle: #bundle),
            value: Text(verbatim: track.discNumber > 0 ? String(track.discNumber) : "—")
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Duration", bundle: #bundle),
            value: Text(verbatim: formatDuration(track.duration))
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Genre", bundle: #bundle),
            value: Text(verbatim: track.genre.isEmpty ? "—" : track.genre)
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Year", bundle: #bundle),
            value: Text(verbatim: track.year.map(String.init) ?? "—")
          )
        }

        if !track.fallbackFields.isEmpty {
          Section {
            Text(String(localized: "i18n:TrackInfo.FallbackNotice", bundle: #bundle))
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        // 檔案資訊
        Section(String(localized: "i18n:TrackInfo.Sections.FileInfo", bundle: #bundle)) {
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.FilePath", bundle: #bundle),
            value: Text(verbatim: track.fileURL.path)
          )
          if let fileSize = detailedMetadata?.fileSize {
            InfoRow(
              label: Text("i18n:TrackInfo.Labels.FileSize", bundle: #bundle),
              value: Text(verbatim: formatFileSize(fileSize))
            )
          }
        }

        // 音訊格式資訊
        if let detailed = detailedMetadata {
          Section(String(localized: "i18n:TrackInfo.Sections.AudioFormat", bundle: #bundle)) {
            InfoRow(
              label: Text("i18n:TrackInfo.Labels.Codec", bundle: #bundle),
              value: Text(verbatim: detailed.codec?.uppercased() ?? "—")
            )
            if let bitDepth = detailed.bitDepth {
              InfoRow(
                label: Text("i18n:TrackInfo.Labels.BitDepth", bundle: #bundle),
                value: Text("i18n:TrackInfo.Values.BitDepthFormat:\(bitDepth)", bundle: #bundle)
              )
            }
            if let sampleRate = detailed.sampleRate {
              InfoRow(
                label: Text("i18n:TrackInfo.Labels.SampleRate", bundle: #bundle),
                value: Text(verbatim: formatSampleRate(sampleRate))
              )
            }
            if let channelCount = detailed.channelCount {
              InfoRow(
                label: Text("i18n:TrackInfo.Labels.Channels", bundle: #bundle),
                value: channelCount == 1 ? Text("i18n:TrackInfo.Values.Mono", bundle: #bundle) :
                  Text("i18n:TrackInfo.Values.ChannelCountFormat:\(channelCount)", bundle: #bundle)
              )
            }
            if let bitrate = detailed.bitrate {
              // Phase 113: bitrate is stored in bps; divide by 1024 and round to nearest kbps.
              let kbps = (bitrate + 512) / 1024
              InfoRow(
                label: Text("i18n:TrackInfo.Labels.Bitrate", bundle: #bundle),
                value: Text("i18n:TrackInfo.Values.BitrateFormat:\(kbps)", bundle: #bundle)
              )
            }
          }
        }
      }
      .navigationTitle(String(localized: "i18n:TrackInfo.Title", bundle: #bundle))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "i18n:Common.Done", bundle: #bundle)) { dismiss() }
        }
      }
    }
    .frame(minWidth: 380, idealWidth: 420, minHeight: 400)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  private let track: Track
  private let detailedMetadata: DetailedTrackMetadata?
}

// MARK: - MultiTrackInfoView

/// 多曲目的「取得資訊」視圖，顯示聚合統計資訊。
struct MultiTrackInfoView: View {
  // MARK: Lifecycle

  init(
    tracks: [Track],
    detailedMetadataList: [DetailedTrackMetadata?]
  ) {
    self.tracks = tracks
    self.detailedMetadataList = detailedMetadataList
  }

  // MARK: Internal

  var body: some View {
    NavigationStack {
      List {
        // 統計資訊
        Section(String(localized: "i18n:TrackInfo.Sections.Statistics", bundle: #bundle)) {
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.Tracks", bundle: #bundle),
            value: Text(verbatim: "\(tracks.count)")
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.TotalDuration", bundle: #bundle),
            value: Text(verbatim: formatDuration(totalDuration))
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.TotalFileSize", bundle: #bundle),
            value: Text(verbatim: totalFileSize.map(formatFileSize) ?? "—")
          )
          InfoRow(
            label: Text("i18n:TrackInfo.Labels.AverageTrackLength", bundle: #bundle),
            value: Text(verbatim: formatDuration(averageDuration))
          )

          if let commonAlbum = commonAlbum, !commonAlbum.isEmpty {
            InfoRow(
              label: Text("i18n:TrackInfo.Labels.Album", bundle: #bundle),
              value: Text(verbatim: commonAlbum)
            )
          }
          if let commonArtist = commonArtist, !commonArtist.isEmpty {
            InfoRow(
              label: Text("i18n:TrackInfo.Labels.Artist", bundle: #bundle),
              value: Text(verbatim: commonArtist)
            )
          }
          if let commonAlbumArtist = commonAlbumArtist, !commonAlbumArtist.isEmpty {
            InfoRow(
              label: Text("i18n:TrackInfo.Labels.AlbumArtist", bundle: #bundle),
              value: Text(verbatim: commonAlbumArtist)
            )
          }
          if let yearRange = yearRange {
            InfoRow(
              label: Text("i18n:TrackInfo.Labels.YearRange", bundle: #bundle),
              value: Text(verbatim: yearRange)
            )
          }
        }

        // 音訊格式統計
        Section(String(localized: "i18n:TrackInfo.Sections.AudioFormats", bundle: #bundle)) {
          ForEach(Array(codecCounts.sorted(by: { $0.value > $1.value })), id: \.key) { codec, count in
            InfoRow(
              label: codec.isEmpty
                ? Text("i18n:TrackInfo.Values.Unknown", bundle: #bundle)
                : Text(verbatim: codec),
              value: Text("i18n:Unit:Track:\(count)", bundle: #bundle)
            )
          }
        }
      }
      .navigationTitle(String(localized: "i18n:TrackInfo.MultipleTracksTitle", bundle: #bundle))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "i18n:Common.Done", bundle: #bundle)) { dismiss() }
        }
      }
    }
    .frame(minWidth: 380, idealWidth: 420, minHeight: 300)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  private let tracks: [Track]
  private let detailedMetadataList: [DetailedTrackMetadata?]

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
  // MARK: Lifecycle

  init(label: Text, value: Text, isFallback: Bool = false) {
    self.label = label
    self.value = value
    self.isFallback = isFallback
  }

  // MARK: Internal

  var body: some View {
    LabeledContent {
      value
        .strikethrough(isFallback, color: .secondary)
        .foregroundStyle(isFallback ? .secondary : .primary)
        .textSelection(.enabled)
    } label: {
      label
    }
  }

  // MARK: Private

  private let label: Text
  private let value: Text
  private var isFallback: Bool = false
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
