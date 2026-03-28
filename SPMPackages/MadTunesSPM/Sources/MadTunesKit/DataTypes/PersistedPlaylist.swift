// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - PersistedPlaylist

/// SwiftData 播放清單持久化模型
@Model
final class PersistedPlaylist {
  // MARK: Lifecycle

  init(
    id: UUID,
    name: String,
    trackIDs: [UUID] = [],
    isSystemPlaylist: Bool = false,
    sortIndex: Int = 0,
    kindRawValue: String = PlaylistKind.staticList.rawValue,
    compoundSortData: Data = Data(),
    predicateData: Data = Data(),
    sourceFolderPlaylistIDs: [UUID] = []
  ) {
    self.id = id
    self.name = name
    self.trackIDs = trackIDs
    self.isSystemPlaylist = isSystemPlaylist
    self.sortIndex = sortIndex
    self.kindRawValue = kindRawValue
    self.compoundSortData = compoundSortData
    self.predicateData = predicateData
    self.sourceFolderPlaylistIDs = sourceFolderPlaylistIDs
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var name: String
  var trackIDs: [UUID]
  var isSystemPlaylist: Bool
  var sortIndex: Int
  var kindRawValue: String
  /// Phase 116: Persisted compound sort settings for dynamic playlists (JSON-encoded).
  var compoundSortData: Data = Data()
  /// Phase 117: JSON-encoded PlaylistPredicate for dynamic playlists.
  var predicateData: Data = Data()
  /// Phase 135: Source folder playlist IDs for dynamic playlists.
  var sourceFolderPlaylistIDs: [UUID] = []

  var kind: PlaylistKind {
    PlaylistKind(rawValue: kindRawValue) ?? .staticList
  }

  /// 轉換為應用層的 Playlist 模型
  /// Note: folderURL and folderBookmarkData are loaded separately from PersistedFolderPlaylistMetadata
  func toPlaylist() -> Playlist {
    Playlist(
      id: id,
      name: name,
      trackIDs: trackIDs,
      kind: kind,
      compoundSortData: compoundSortData,
      predicateData: predicateData,
      sourceFolderPlaylistIDSet: Set(sourceFolderPlaylistIDs)
    )
  }
}
