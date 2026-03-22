// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - CachedArtwork

/// Phase 108: SwiftData model for on-disk album artwork cache.
/// Stored in a **separate** ModelContainer from the main tracks database
/// to avoid bloating the primary SQLite file.
@Model
final class CachedArtwork {
  // MARK: Lifecycle

  init(
    albumKey: String,
    imageData: Data,
    dominantColorHue: Double? = nil,
    dominantColorSaturation: Double? = nil,
    dominantColorBrightness: Double? = nil
  ) {
    self.albumKey = albumKey
    self.imageData = imageData
    self.dominantColorHue = dominantColorHue
    self.dominantColorSaturation = dominantColorSaturation
    self.dominantColorBrightness = dominantColorBrightness
  }

  // MARK: Internal

  /// Album key in the format "title:::artist".
  @Attribute(.unique) var albumKey: String

  /// JPEG image data. Stored externally by SQLite to keep the DB file small.
  @Attribute(.externalStorage) var imageData: Data

  /// Pre-computed dominant color HSB components (0…1 range).
  /// Stored once at cache time to avoid per-render pixel scanning.
  var dominantColorHue: Double?
  var dominantColorSaturation: Double?
  var dominantColorBrightness: Double?
}
