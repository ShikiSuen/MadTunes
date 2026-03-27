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
    kind: PlaylistKind = .staticList,
    compoundSortData: Data = Data(),
    predicateData: Data = Data(),
    folderURL: URL? = nil,
    folderBookmarkData: Data? = nil
  ) {
    self.id = id
    self.name = name
    self.trackIDs = trackIDs
    self.kind = kind
    self.compoundSortData = compoundSortData
    self.predicateData = predicateData
    self.folderURL = folderURL
    self.folderBookmarkData = folderBookmarkData
  }

  // MARK: Public

  public let id: UUID
  public var name: String
  public var trackIDs: [UUID]
  public var kind: PlaylistKind
  /// Phase 116: Persisted compound sort settings for dynamic playlists (JSON-encoded).
  /// Empty data means no saved sort. For All Music (system index 0), always empty — uses UserDefaults.
  public var compoundSortData: Data
  /// Phase 117: JSON-encoded PlaylistPredicate for dynamic playlists.
  /// Empty data means no predicate configured (dynamic playlist shows empty).
  public var predicateData: Data
  /// Phase 129: Folder URL for folderList playlists.
  public var folderURL: URL?
  /// Phase 129: Security-scoped bookmark data for the folder URL.
  public var folderBookmarkData: Data?

  /// 是否為系統播放清單（不可刪除）
  public var isSystemPlaylist: Bool {
    kind == .system
  }
}
