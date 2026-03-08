// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

public struct Playlist: Identifiable, Hashable, Sendable {
  // MARK: Lifecycle

  public init(id: UUID = UUID(), name: String, trackIDs: [UUID] = []) {
    self.id = id
    self.name = name
    self.trackIDs = trackIDs
  }

  // MARK: Public

  public let id: UUID
  public var name: String
  public var trackIDs: [UUID]
}
