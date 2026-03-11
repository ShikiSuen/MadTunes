// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

public struct Playlist: Identifiable, Hashable, Sendable {
  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    name: String,
    trackIDs: [UUID] = [],
    kind: PlaylistKind = .staticList
  ) {
    self.id = id
    self.name = name
    self.trackIDs = trackIDs
    self.kind = kind
  }

  // MARK: Public

  public let id: UUID
  public var name: String
  public var trackIDs: [UUID]
  public var kind: PlaylistKind

  /// 是否為系統播放清單（不可刪除）
  public var isSystemPlaylist: Bool {
    kind == .system
  }
}
