// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import AVFoundation

/// Reads audio metadata (title, artist, album, artwork, duration) from a file URL
/// using AVFoundation's AVAsset APIs.
public enum MetadataReader: Sendable {
  // MARK: Public

  public struct TrackMetadata: Sendable {
    public let track: Track
    public let artworkData: Data?
  }

  /// Read metadata from an audio file. Falls back to filename-based Track on failure.
  public static func readTrack(from url: URL) async -> TrackMetadata {
    await readTrackInternal(from: url, includeArtwork: true)
  }

  /// Read metadata without artwork (faster for bulk import).
  public static func readTrackInfo(from url: URL) async -> TrackMetadata {
    await readTrackInternal(from: url, includeArtwork: false)
  }

  /// Read only artwork data from an audio file.
  public static func readArtwork(from url: URL) async -> Data? {
    let asset = AVURLAsset(url: url)
    guard let meta = try? await asset.load(.commonMetadata) else { return nil }
    return await loadData(from: meta, id: .commonIdentifierArtwork)
  }

  /// Check if a file is an iTunes Voice Memo.
  /// Uses authoritative markers:
  /// 1. ID3 tag: `----:com.apple.iTunes:voice-memo-uuid` (definitive Apple marker)
  /// 2. Tool identifier: `com.apple.VoiceMemos` in encoding tool metadata
  /// 3. Fallback: Path check for "Voice Memos" directory
  public static func isVoiceMemo(url: URL) async -> Bool {
    do {
      let asset = AVURLAsset(url: url)
      let allMetadata = try await asset.load(.metadata)

      // Check 1: Look for voice-memo-uuid in iTunes ID3 metadata
      // This is the definitive Apple marker for voice memos
      for item in allMetadata {
        // Check for the iTunes voice memo UUID tag
        if let identifier = item.identifier?.rawValue,
           identifier.contains("voice-memo-uuid") || identifier.contains("voice_memo_uuid") {
          return true
        }

        // Check 2: Check for com.apple.VoiceMemos in tool/encoding information
        if let identifier = item.identifier?.rawValue,
           identifier.contains("tool") || identifier.contains("encoding") || identifier == "©too" {
          if let toolString = try? await item.load(.stringValue),
             toolString.contains("com.apple.VoiceMemos") {
            return true
          }
        }

        // Also check in regular comment/description fields for com.apple.VoiceMemos
        if let toolString = try? await item.load(.stringValue),
           toolString.contains("com.apple.VoiceMemos") {
          return true
        }
      }

      // Check 3: Fallback to path check
      let pathComponents = url.pathComponents
      if pathComponents.contains("Voice Memos") || pathComponents.contains("VoiceMemos") {
        return true
      }
    } catch {
      // If metadata can't be read, fall back to path check
      let pathComponents = url.pathComponents
      if pathComponents.contains("Voice Memos") || pathComponents.contains("VoiceMemos") {
        return true
      }
    }

    return false
  }

  // MARK: - Detailed Metadata

  /// 讀取詳盡的音軌中繼資料，包括音訊格式資訊。
  public static func readDetailedMetadata(from url: URL) async -> DetailedTrackMetadata {
    let asset = AVURLAsset(url: url)

    // 獲取檔案大小
    let fileSize: Int64? = {
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64
      } catch {
        return nil
      }
    }()

    // 從音軌讀取音訊格式資訊
    var bitDepth: Int?
    var sampleRate: Double?
    var codec: String?
    var channelCount: Int?
    var bitrate: Int?

    do {
      let tracks = try await asset.load(.tracks)
      if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        if let formatDesc = formatDescriptions.first {
          // 獲取 codec 資訊
          let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDesc)
          codec = formatFourCCToString(mediaSubType)

          // 獲取取樣率和聲道數
          if let basicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
            sampleRate = basicDesc.pointee.mSampleRate
            channelCount = Int(basicDesc.pointee.mChannelsPerFrame)
            bitDepth = Int(basicDesc.pointee.mBitsPerChannel)

            // 計算位元率（如果可用）
            if basicDesc.pointee.mBytesPerFrame > 0, basicDesc.pointee.mFramesPerPacket > 0 {
              let bytesPerPacket = basicDesc.pointee.mBytesPerPacket
              let framesPerPacket = basicDesc.pointee.mFramesPerPacket
              if bytesPerPacket > 0, framesPerPacket > 0, sampleRate != nil {
                // 對於未壓縮音訊：bitrate = sampleRate * bytesPerFrame * channels
                // 對於壓縮音訊，我們需要估算
                bitrate = Int(Double(bytesPerPacket) * sampleRate! / Double(framesPerPacket) * 8)
              }
            }
          }
        }

        // 嘗試從 estimatedDataRate 獲取位元率
        if bitrate == nil {
          let dataRate = try await audioTrack.load(.estimatedDataRate)
          if dataRate > 0 {
            bitrate = Int(dataRate) // estimatedDataRate 已是 bps
          }
        }
      }
    } catch {
      // 忽略錯誤，返回已獲取的資訊
    }

    return DetailedTrackMetadata(
      bitDepth: bitDepth,
      sampleRate: sampleRate,
      codec: codec,
      bitrate: bitrate,
      fileSize: fileSize,
      channelCount: channelCount
    )
  }

  // MARK: Private

  private static func readTrackInternal(from url: URL, includeArtwork: Bool) async -> TrackMetadata {
    do {
      let asset = AVURLAsset(url: url)
      let commonMeta = try await asset.load(.commonMetadata)
      let durationCM = try await asset.load(.duration)
      let duration = CMTimeGetSeconds(durationCM)

      let title = await loadString(from: commonMeta, id: .commonIdentifierTitle)
      let artist = await loadString(from: commonMeta, id: .commonIdentifierArtist)
      let albumName = await loadString(from: commonMeta, id: .commonIdentifierAlbumName)
      let artworkData = includeArtwork
        ? await loadData(from: commonMeta, id: .commonIdentifierArtwork)
        : nil

      // Try to read album artist from iTunes metadata.
      let iTunesMeta = try await asset.load(.metadata)
      let albumArtist = await loadString(
        from: iTunesMeta,
        id: .iTunesMetadataAlbumArtist
      )
      let composer = await loadString(
        from: iTunesMeta,
        id: .iTunesMetadataComposer
      )

      let trackNumber = await loadTrackOrDiscNumber(
        from: iTunesMeta,
        identifiers: [.iTunesMetadataTrackNumber, .id3MetadataTrackNumber]
      ) ?? 0

      let discNumber = await loadTrackOrDiscNumber(
        from: iTunesMeta,
        identifiers: [.iTunesMetadataDiscNumber, .id3MetadataPartOfASet]
      ) ?? 0

      let year: Int?
      if let commonYear = await loadYear(from: commonMeta) {
        year = commonYear
      } else {
        year = await loadYear(from: iTunesMeta, id: .iTunesMetadataReleaseDate)
      }

      // Genre: try iTunes user genre, ID3 content type (TCON), QuickTime genre.
      var genre = ""
      if let g = await loadString(from: iTunesMeta, id: .iTunesMetadataUserGenre) {
        genre = g
      } else if let g = await loadString(from: iTunesMeta, id: .id3MetadataContentType) {
        genre = g
      } else if let g = await loadString(from: iTunesMeta, id: .quickTimeMetadataGenre) {
        genre = g
      }

      // Fallback chains:
      // - Artist: metadata artist → composer → album artist → "Unknown Artist"
      // - Album: metadata album → track title → "Unknown Album"
      let effectiveArtist: String

      if let artist, !artist.isEmpty {
        effectiveArtist = artist
      } else if let composer, !composer.isEmpty {
        effectiveArtist = composer
      } else if let albumArtist, !albumArtist.isEmpty {
        effectiveArtist = albumArtist
      } else {
        effectiveArtist = "Unknown Artist"
      }

      let effectiveAlbumTitle: String
      if let albumName, !albumName.isEmpty {
        effectiveAlbumTitle = albumName
      } else if let title, !title.isEmpty {
        effectiveAlbumTitle = title
      } else {
        effectiveAlbumTitle =
          "Unknown Album"
      }

      let track = Track(
        fileURL: url,
        title: title,
        artist: effectiveArtist,
        albumTitle: effectiveAlbumTitle,
        albumArtist: albumArtist ?? "",
        trackNumber: trackNumber,
        discNumber: discNumber,
        duration: duration.isFinite ? duration : 0,
        genre: genre,
        year: year
      )

      return TrackMetadata(track: track, artworkData: artworkData)
    } catch {
      let track = Track(fileURL: url)
      return TrackMetadata(track: track, artworkData: nil)
    }
  }

  // MARK: - Private Helpers

  private static func loadString(
    from items: [AVMetadataItem],
    id: AVMetadataIdentifier
  ) async
    -> String? {
    let filtered = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id)
    guard let item = filtered.first else { return nil }
    return try? await item.load(.stringValue)
  }

  private static func loadData(
    from items: [AVMetadataItem],
    id: AVMetadataIdentifier
  ) async
    -> Data? {
    let filtered = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id)
    guard let item = filtered.first else { return nil }
    return try? await item.load(.dataValue)
  }

  /// Try multiple identifiers to extract an integer (track number or disc number).
  /// Handles numberValue, "3/12" string format, and raw MP4 binary data.
  private static func loadTrackOrDiscNumber(
    from items: [AVMetadataItem],
    identifiers: [AVMetadataIdentifier]
  ) async
    -> Int? {
    for id in identifiers {
      let filtered = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id)
      guard let item = filtered.first else { continue }
      if let num = try? await item.load(.numberValue), num.intValue > 0 {
        return num.intValue
      }
      if let str = try? await item.load(.stringValue),
         let part = str.split(separator: "/").first,
         let n = Int(part), n > 0 {
        return n
      }
      // MP4 trkn/disk atom: 2 reserved bytes + UInt16 big-endian value + UInt16 total
      if let data = try? await item.load(.dataValue), data.count >= 4 {
        let value = Int(data[2]) << 8 | Int(data[3])
        if value > 0 { return value }
      }
    }
    return nil
  }

  private static func loadYear(
    from items: [AVMetadataItem],
    id: AVMetadataIdentifier = .commonIdentifierCreationDate
  ) async
    -> Int? {
    guard let dateStr = await loadString(from: items, id: id)
    else { return nil }
    let trimmed = dateStr.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= 4, let year = Int(trimmed.prefix(4)), year > 0
    else { return nil }
    return year
  }

  /// 將 FourCC 代碼轉換為可讀的字串
  private static func formatFourCCToString(_ fourcc: FourCharCode) -> String {
    let bytes: [UInt8] = [
      UInt8((fourcc >> 24) & 0xFF),
      UInt8((fourcc >> 16) & 0xFF),
      UInt8((fourcc >> 8) & 0xFF),
      UInt8(fourcc & 0xFF),
    ]
    return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
  }
}
