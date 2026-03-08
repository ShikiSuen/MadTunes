// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
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

      // Fallback chains:
      // - Artist: metadata artist → composer → "Unknown Artist"
      // - Album: metadata album → track title → "Unknown Album"
      let effectiveArtist: String
      if let artist, !artist.isEmpty { effectiveArtist = artist } else if let composer,
                                                                          !composer
                                                                          .isEmpty { effectiveArtist = composer }
      else { effectiveArtist = "Unknown Artist" }

      let effectiveAlbumTitle: String
      if let albumName, !albumName.isEmpty { effectiveAlbumTitle = albumName } else if let title,
                                                                                       !title
                                                                                       .isEmpty {
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
}
