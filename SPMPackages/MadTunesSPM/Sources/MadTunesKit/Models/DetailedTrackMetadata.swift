// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - DetailedTrackMetadata

/// 詳盡的音軌中繼資料，用於「取得資訊」功能。
public struct DetailedTrackMetadata: Sendable {
  // MARK: Lifecycle

  public init(
    bitDepth: Int? = nil,
    sampleRate: Double? = nil,
    codec: String? = nil,
    bitrate: Int? = nil,
    fileSize: Int64? = nil,
    channelCount: Int? = nil
  ) {
    self.bitDepth = bitDepth
    self.sampleRate = sampleRate
    self.codec = codec
    self.bitrate = bitrate
    self.fileSize = fileSize
    self.channelCount = channelCount
  }

  // MARK: Public

  /// 位元深度，例如 16、24、32
  public let bitDepth: Int?
  /// 取樣率，例如 44100.0、96000.0
  public let sampleRate: Double?
  /// 編碼格式，例如 "AAC"、"ALAC"、"FLAC"
  public let codec: String?
  /// 位元率（bps）
  public let bitrate: Int?
  /// 檔案大小（bytes）
  public let fileSize: Int64?
  /// 聲道數，例如 2
  public let channelCount: Int?
}

// MARK: - Track + DetailedMetadata

extension Track {
  /// 將 Track 的中繼資料轉換為 TSV（Tab-Separated Values）格式的字串
  public func toTSVRow() -> String {
    let fields = [
      title,
      artist,
      albumTitle,
      String(trackNumber),
      String(discNumber),
      formatDuration(duration),
      genre,
      year.map(String.init) ?? "",
      fileURL.path,
    ]
    return fields.joined(separator: "\t")
  }

  /// TSV 標頭欄位名稱
  public static let tsvHeader: String = "Title\tArtist\tAlbum\tTrack#\tDisc#\tDuration\tGenre\tYear\tFilePath"
}

/// 將多個 Track 的中繼資料轉換為 TSV 格式（含標頭）
public func tracksToTSV(_ tracks: [Track]) -> String {
  var lines = [Track.tsvHeader]
  lines.append(contentsOf: tracks.map { $0.toTSVRow() })
  return lines.joined(separator: "\n")
}
