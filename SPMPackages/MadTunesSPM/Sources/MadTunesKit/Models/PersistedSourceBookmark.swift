// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

/// Persists security-scoped bookmarks for user-selected import source URLs
/// (directories or individual files). On relaunch, resolving these bookmarks
/// restores security-scoped access so that all child files remain accessible.
@Model
final class PersistedSourceBookmark {
  // MARK: Lifecycle

  init(urlString: String, bookmarkData: Data) {
    self.urlString = urlString
    self.bookmarkData = bookmarkData
  }

  // MARK: Internal

  @Attribute(.unique) var urlString: String
  var bookmarkData: Data
}
