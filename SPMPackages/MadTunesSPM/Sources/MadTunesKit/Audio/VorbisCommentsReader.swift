// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - VorbisCommentsReader

/// Phase 125/126: Unified Vorbis Comments metadata reader for FLAC, OGG Vorbis, and Opus files.
///
/// All three formats share the same Vorbis Comments binary layout for metadata fields
/// and the same PICTURE block format for embedded artwork. They differ only in the
/// container format:
///   - FLAC: `fLaC` magic → metadata block headers (type 4 = Vorbis Comment, type 6 = PICTURE)
///   - OGG Vorbis: `OggS` pages → second logical packet with `\x03vorbis` prefix
///   - Opus: `OggS` pages → second logical packet with `OpusTags` prefix
///
/// Artwork in OGG/Opus is embedded as `METADATA_BLOCK_PICTURE` Vorbis Comment entries
/// (Base64-encoded FLAC PICTURE blocks).
enum VorbisCommentsReader: Sendable {
  // MARK: Internal

  // MARK: - Public Types

  struct VorbisComments: Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var trackNumber: Int?
    var discNumber: Int?
    var genre: String?
    var year: Int?
    var composer: String?
  }

  // MARK: - Public API

  /// Parse Vorbis Comments from a FLAC, OGG, or Opus file (auto-detected by extension).
  static func parseVorbisComments(from url: URL) -> VorbisComments? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    switch url.pathExtension.lowercased() {
    case "flac": return parseFLACVorbisComments(from: data)
    case "ogg", "opus": return parseOggVorbisComments(from: data)
    default: return nil
    }
  }

  /// Parse artwork from a FLAC, OGG, or Opus file (auto-detected by extension).
  static func parsePicture(from url: URL) -> Data? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    switch url.pathExtension.lowercased() {
    case "flac": return parseFLACPicture(from: data)
    case "ogg", "opus": return parseOggPicture(from: data)
    default: return nil
    }
  }

  // MARK: Private

  // MARK: - FLAC Container

  /// FLAC metadata block types.
  private enum FLACBlockType: UInt8 {
    case streamInfo = 0
    case padding = 1
    case application = 2
    case seekTable = 3
    case vorbisComment = 4
    case cueSheet = 5
    case picture = 6
  }

  // MARK: - Ogg Container

  /// Magic bytes for an Ogg page header.
  private static let oggMagic: [UInt8] = [0x4F, 0x67, 0x67, 0x53] // "OggS"

  // MARK: - Vorbis Comment Decoding (shared across all formats)

  /// Decode a VORBIS_COMMENT metadata block.
  /// Layout: vendor_length(LE32) + vendor_string + num_comments(LE32)
  ///         + for each: comment_length(LE32) + "KEY=value" (UTF-8)
  private static func decodeVorbisComments(_ blockData: Data) -> VorbisComments? {
    var result = VorbisComments()
    var pos = blockData.startIndex

    // Vendor string (skip).
    guard pos + 4 <= blockData.endIndex else { return nil }
    let vendorLength = readLE32(blockData, at: pos)
    pos += 4
    guard pos + vendorLength <= blockData.endIndex else { return nil }
    pos += vendorLength

    // Number of comments.
    guard pos + 4 <= blockData.endIndex else { return nil }
    let numComments = readLE32(blockData, at: pos)
    pos += 4

    for _ in 0 ..< numComments {
      guard pos + 4 <= blockData.endIndex else { break }
      let commentLength = readLE32(blockData, at: pos)
      pos += 4
      guard pos + commentLength <= blockData.endIndex else { break }

      let commentBytes = blockData[pos ..< pos + commentLength]
      pos += commentLength

      guard let comment = String(data: Data(commentBytes), encoding: .utf8),
            let eqIndex = comment.firstIndex(of: "=") else { continue }

      let key = comment[comment.startIndex ..< eqIndex].uppercased()
      let value = String(comment[comment.index(after: eqIndex)...])

      switch key {
      case "TITLE":
        result.title = value
      case "ARTIST":
        result.artist = value
      case "ALBUM":
        result.album = value
      case "ALBUM ARTIST", "ALBUMARTIST":
        result.albumArtist = value
      case "TRACKNUMBER":
        result.trackNumber = parseLeadingInt(value)
      case "DISCNUMBER":
        result.discNumber = parseLeadingInt(value)
      case "GENRE":
        result.genre = value
      case "DATE", "YEAR":
        if let yr = parseLeadingInt(String(value.prefix(4))), yr > 0 {
          result.year = yr
        }
      case "COMPOSER":
        result.composer = value
      default:
        break
      }
    }
    return result
  }

  // MARK: - PICTURE Block Decoding (shared across all formats)

  /// Decode a PICTURE metadata block.
  /// Layout: type(BE32) + mime_len(BE32) + mime + desc_len(BE32) + desc
  ///         + width(BE32) + height(BE32) + depth(BE32) + colors(BE32)
  ///         + data_len(BE32) + data
  private static func decodePictureBlock(_ blockData: Data) -> (pictureType: UInt32, data: Data)? {
    var pos = blockData.startIndex

    guard pos + 4 <= blockData.endIndex else { return nil }
    let pictureType = readBE32(blockData, at: pos)
    pos += 4

    // MIME type.
    guard pos + 4 <= blockData.endIndex else { return nil }
    let mimeLength = Int(readBE32(blockData, at: pos))
    pos += 4
    guard pos + mimeLength <= blockData.endIndex else { return nil }
    pos += mimeLength

    // Description.
    guard pos + 4 <= blockData.endIndex else { return nil }
    let descLength = Int(readBE32(blockData, at: pos))
    pos += 4
    guard pos + descLength <= blockData.endIndex else { return nil }
    pos += descLength

    // Width, height, depth, colors (skip).
    guard pos + 16 <= blockData.endIndex else { return nil }
    pos += 16

    // Image data.
    guard pos + 4 <= blockData.endIndex else { return nil }
    let dataLength = Int(readBE32(blockData, at: pos))
    pos += 4
    guard pos + dataLength <= blockData.endIndex else { return nil }

    let imageData = Data(blockData[pos ..< pos + dataLength])
    return (pictureType, imageData)
  }

  // MARK: - Binary Helpers

  private static func readLE32(_ data: Data, at offset: Data.Index) -> Int {
    Int(data[offset])
      | Int(data[offset + 1]) << 8
      | Int(data[offset + 2]) << 16
      | Int(data[offset + 3]) << 24
  }

  private static func readBE32(_ data: Data, at offset: Data.Index) -> UInt32 {
    UInt32(data[offset]) << 24
      | UInt32(data[offset + 1]) << 16
      | UInt32(data[offset + 2]) << 8
      | UInt32(data[offset + 3])
  }

  /// Parse an integer from the leading portion of a string (e.g., "3/12" → 3).
  private static func parseLeadingInt(_ str: String) -> Int? {
    let trimmed = str.trimmingCharacters(in: .whitespaces)
    if let slashIndex = trimmed.firstIndex(of: "/") {
      return Int(trimmed[trimmed.startIndex ..< slashIndex])
    }
    return Int(trimmed)
  }

  private static func parseFLACVorbisComments(from data: Data) -> VorbisComments? {
    guard data.count >= 4,
          data[0] == 0x66, data[1] == 0x4C, data[2] == 0x61, data[3] == 0x43 // "fLaC"
    else { return nil }

    var offset = 4
    while offset + 4 <= data.count {
      let header = data[offset]
      let isLast = (header & 0x80) != 0
      let blockType = header & 0x7F
      let blockLength = Int(data[offset + 1]) << 16
        | Int(data[offset + 2]) << 8
        | Int(data[offset + 3])
      offset += 4

      guard offset + blockLength <= data.count else { break }

      if blockType == FLACBlockType.vorbisComment.rawValue {
        let blockData = data[offset ..< offset + blockLength]
        return decodeVorbisComments(blockData)
      }

      offset += blockLength
      if isLast { break }
    }
    return nil
  }

  private static func parseFLACPicture(from data: Data) -> Data? {
    guard data.count >= 4,
          data[0] == 0x66, data[1] == 0x4C, data[2] == 0x61, data[3] == 0x43 // "fLaC"
    else { return nil }

    var offset = 4
    var fallbackPictureData: Data?

    while offset + 4 <= data.count {
      let header = data[offset]
      let isLast = (header & 0x80) != 0
      let blockType = header & 0x7F
      let blockLength = Int(data[offset + 1]) << 16
        | Int(data[offset + 2]) << 8
        | Int(data[offset + 3])
      offset += 4

      guard offset + blockLength <= data.count else { break }

      if blockType == FLACBlockType.picture.rawValue {
        let blockData = data[offset ..< offset + blockLength]
        if let (pictureType, imageData) = decodePictureBlock(blockData) {
          // Type 3 = front cover (preferred).
          if pictureType == 3 { return imageData }
          if fallbackPictureData == nil { fallbackPictureData = imageData }
        }
      }

      offset += blockLength
      if isLast { break }
    }
    return fallbackPictureData
  }

  private static func parseOggVorbisComments(from data: Data) -> VorbisComments? {
    guard let commentPayload = extractOggCommentPayload(from: data) else { return nil }
    return decodeVorbisComments(commentPayload)
  }

  private static func parseOggPicture(from data: Data) -> Data? {
    guard let commentPayload = extractOggCommentPayload(from: data) else { return nil }
    return decodeOggPictureFromComments(commentPayload)
  }

  /// Extract the Vorbis Comment payload from the Ogg stream.
  /// Returns the raw comment data (after stripping the codec-specific prefix).
  private static func extractOggCommentPayload(from data: Data) -> Data? {
    var packets: [Data] = []
    var offset = 0
    var currentPacketData = Data()

    // We only need the first two packets (identification + comment).
    while offset + 27 <= data.count, packets.count < 2 {
      // Verify OggS capture pattern.
      guard data[offset] == oggMagic[0],
            data[offset + 1] == oggMagic[1],
            data[offset + 2] == oggMagic[2],
            data[offset + 3] == oggMagic[3]
      else { break }

      // Parse page header.
      let numSegments = Int(data[offset + 26])
      let segTableStart = offset + 27
      guard segTableStart + numSegments <= data.count else { break }

      // Read segment table.
      var segmentSizes: [Int] = []
      var totalPageDataSize = 0
      for i in 0 ..< numSegments {
        let segSize = Int(data[segTableStart + i])
        segmentSizes.append(segSize)
        totalPageDataSize += segSize
      }

      let pageDataStart = segTableStart + numSegments
      guard pageDataStart + totalPageDataSize <= data.count else { break }

      // Reassemble packets from segments.
      var segDataOffset = pageDataStart
      for segSize in segmentSizes {
        currentPacketData.append(data[segDataOffset ..< segDataOffset + segSize])
        segDataOffset += segSize

        // A segment < 255 bytes completes the current packet.
        if segSize < 255 {
          packets.append(currentPacketData)
          currentPacketData = Data()
          if packets.count >= 2 { break }
        }
      }

      offset = pageDataStart + totalPageDataSize
    }

    // We need at least 2 packets (identification + comment).
    guard packets.count >= 2 else { return nil }
    let commentPacket = packets[1]

    // Strip codec-specific prefix to get raw Vorbis Comment data.
    // Vorbis: "\x03vorbis" (7 bytes)
    let vorbisPrefix: [UInt8] = [0x03, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]
    // Opus: "OpusTags" (8 bytes)
    let opusPrefix: [UInt8] = [0x4F, 0x70, 0x75, 0x73, 0x54, 0x61, 0x67, 0x73]

    if commentPacket.count > vorbisPrefix.count,
       Array(commentPacket.prefix(vorbisPrefix.count)) == vorbisPrefix {
      return commentPacket.dropFirst(vorbisPrefix.count) as Data
    } else if commentPacket.count > opusPrefix.count,
              Array(commentPacket.prefix(opusPrefix.count)) == opusPrefix {
      return commentPacket.dropFirst(opusPrefix.count) as Data
    }

    return nil
  }

  // MARK: - Ogg METADATA_BLOCK_PICTURE Decoding

  /// Scan Vorbis Comments for METADATA_BLOCK_PICTURE entries.
  /// Each value is a Base64-encoded FLAC PICTURE block.
  /// Returns image data from the first front cover (type 3), or any picture as fallback.
  private static func decodeOggPictureFromComments(_ commentData: Data) -> Data? {
    var pos = commentData.startIndex

    // Skip vendor string.
    guard pos + 4 <= commentData.endIndex else { return nil }
    let vendorLength = readLE32(commentData, at: pos)
    pos += 4
    guard pos + vendorLength <= commentData.endIndex else { return nil }
    pos += vendorLength

    // Number of comments.
    guard pos + 4 <= commentData.endIndex else { return nil }
    let numComments = readLE32(commentData, at: pos)
    pos += 4

    var fallbackPictureData: Data?

    for _ in 0 ..< numComments {
      guard pos + 4 <= commentData.endIndex else { break }
      let commentLength = readLE32(commentData, at: pos)
      pos += 4
      guard pos + commentLength <= commentData.endIndex else { break }

      let commentBytes = commentData[pos ..< pos + commentLength]
      pos += commentLength

      guard let comment = String(data: Data(commentBytes), encoding: .utf8),
            let eqIndex = comment.firstIndex(of: "=")
      else { continue }

      let key = comment[comment.startIndex ..< eqIndex].uppercased()
      guard key == "METADATA_BLOCK_PICTURE" else { continue }

      let base64Value = String(comment[comment.index(after: eqIndex)...])
      guard let pictureBlockData = Data(base64Encoded: base64Value) else { continue }

      if let (pictureType, imageData) = decodePictureBlock(pictureBlockData) {
        if pictureType == 3 { return imageData }
        if fallbackPictureData == nil { fallbackPictureData = imageData }
      }
    }
    return fallbackPictureData
  }
}
