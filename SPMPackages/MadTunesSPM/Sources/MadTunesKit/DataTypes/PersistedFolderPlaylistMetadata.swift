// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - PersistedFolderPlaylistMetadata

/// Phase 129: SwiftData model for folder playlist metadata.
/// Stores the folder URL, security-scoped bookmark, and cached track IDs.
@Model
final class PersistedFolderPlaylistMetadata {
  // MARK: Lifecycle

  init(
    playlistID: UUID,
    folderURLString: String,
    folderBookmarkData: Data,
    cachedTrackIDsData: Data = Data(),
    lastScannedAt: Date? = nil
  ) {
    self.playlistID = playlistID
    self.folderURLString = folderURLString
    self.folderBookmarkData = folderBookmarkData
    self.cachedTrackIDsData = cachedTrackIDsData
    self.lastScannedAt = lastScannedAt
  }

  // MARK: Internal

  /// The ID of the associated PersistedPlaylist (foreign key).
  @Attribute(.unique) var playlistID: UUID

  /// The folder URL as a string.
  var folderURLString: String

  /// Security-scoped bookmark data for the folder URL.
  var folderBookmarkData: Data

  /// JSON-encoded array of cached track UUIDs.
  /// These IDs are NOT in the main library's tracks array.
  var cachedTrackIDsData: Data

  /// Timestamp of the last folder scan.
  var lastScannedAt: Date?

  /// The folder URL reconstructed from the string.
  var folderURL: URL? {
    URL(string: folderURLString)
  }

  /// Decode cached track IDs from JSON data.
  var cachedTrackIDs: [UUID] {
    guard !cachedTrackIDsData.isEmpty,
          let ids = try? JSONDecoder().decode([UUID].self, from: cachedTrackIDsData)
    else { return [] }
    return ids
  }

  /// Encode and store track IDs as JSON data.
  func updateCachedTrackIDs(_ ids: [UUID]) {
    cachedTrackIDsData = (try? JSONEncoder().encode(ids)) ?? Data()
    lastScannedAt = Date()
  }
}
