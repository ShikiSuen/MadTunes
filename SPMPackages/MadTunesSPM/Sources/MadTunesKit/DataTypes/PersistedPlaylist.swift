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
    kindRawValue: String = PlaylistKind.staticList.rawValue
  ) {
    self.id = id
    self.name = name
    self.trackIDs = trackIDs
    self.isSystemPlaylist = isSystemPlaylist
    self.sortIndex = sortIndex
    self.kindRawValue = kindRawValue
  }

  // MARK: Internal

  @Attribute(.unique, originalName: "playlistID") var id: UUID
  var name: String
  var trackIDs: [UUID]
  var isSystemPlaylist: Bool
  var sortIndex: Int
  var kindRawValue: String

  var kind: PlaylistKind {
    PlaylistKind(rawValue: kindRawValue) ?? .staticList
  }

  /// 轉換為應用層的 Playlist 模型
  func toPlaylist() -> Playlist {
    Playlist(
      id: id,
      name: name,
      trackIDs: trackIDs,
      kind: kind
    )
  }
}
