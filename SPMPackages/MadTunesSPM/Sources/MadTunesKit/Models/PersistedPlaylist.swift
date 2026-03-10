// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
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
    playlistID: String,
    name: String,
    trackIDStrings: [String] = [],
    isSystemPlaylist: Bool = false,
    sortIndex: Int = 0,
    kindRawValue: String = PlaylistKind.staticList.rawValue
  ) {
    self.playlistID = playlistID
    self.name = name
    self.trackIDStrings = trackIDStrings
    self.isSystemPlaylist = isSystemPlaylist
    self.sortIndex = sortIndex
    self.kindRawValue = kindRawValue
  }

  // MARK: Internal

  @Attribute(.unique) var playlistID: String
  var name: String
  var trackIDStrings: [String]
  var isSystemPlaylist: Bool
  var sortIndex: Int
  var kindRawValue: String

  var kind: PlaylistKind {
    PlaylistKind(rawValue: kindRawValue) ?? .staticList
  }

  /// 轉換為應用層的 Playlist 模型
  func toPlaylist() -> Playlist? {
    guard let id = UUID(uuidString: playlistID) else { return nil }
    let trackIDs = trackIDStrings.compactMap { UUID(uuidString: $0) }
    return Playlist(
      id: id,
      name: name,
      trackIDs: trackIDs,
      kind: kind
    )
  }
}
