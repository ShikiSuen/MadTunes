// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - ArtworkCacheStore

/// Phase 108: Background actor for reading/writing artwork to a dedicated SwiftData container.
/// Uses `@ModelActor` to keep all SQLite I/O off the main thread.
@ModelActor
public actor ArtworkCacheStore {
  /// Fetch artwork data and pre-computed dominant color for a given album key.
  func fetchArtwork(forKey key: String) -> ArtworkCacheResult? {
    var descriptor = FetchDescriptor<CachedArtwork>(
      predicate: #Predicate { $0.albumKey == key }
    )
    descriptor.fetchLimit = 1
    guard let cached = try? modelContext.fetch(descriptor).first else { return nil }
    return ArtworkCacheResult(
      data: cached.imageData,
      dominantColorHue: cached.dominantColorHue,
      dominantColorSaturation: cached.dominantColorSaturation,
      dominantColorBrightness: cached.dominantColorBrightness
    )
  }

  /// Store artwork data along with pre-computed dominant color.
  func store(
    imageData: Data,
    dominantColorHue: Double?,
    dominantColorSaturation: Double?,
    dominantColorBrightness: Double?,
    forKey key: String
  ) {
    var descriptor = FetchDescriptor<CachedArtwork>(
      predicate: #Predicate { $0.albumKey == key }
    )
    descriptor.fetchLimit = 1
    if let existing = try? modelContext.fetch(descriptor).first {
      existing.imageData = imageData
      existing.dominantColorHue = dominantColorHue
      existing.dominantColorSaturation = dominantColorSaturation
      existing.dominantColorBrightness = dominantColorBrightness
    } else {
      modelContext.insert(CachedArtwork(
        albumKey: key,
        imageData: imageData,
        dominantColorHue: dominantColorHue,
        dominantColorSaturation: dominantColorSaturation,
        dominantColorBrightness: dominantColorBrightness
      ))
    }
    try? modelContext.save()
  }

  /// Remove all cached artworks (used when clearing the database).
  func removeAll() {
    try? modelContext.delete(model: CachedArtwork.self)
    try? modelContext.save()
  }

  /// Phase 129: Remove orphaned artwork caches that no longer have matching albums.
  /// Call this after `loadPersistedData()` to clean up stale entries.
  func cleanupOrphanedCaches(activeAlbumKeys: Set<String>) {
    guard !activeAlbumKeys.isEmpty else {
      // If no active albums, clear all caches (app has no tracks).
      removeAll()
      return
    }

    // Fetch all cached artwork keys
    let descriptor = FetchDescriptor<CachedArtwork>()
    guard let allCached = try? modelContext.fetch(descriptor) else { return }

    // Delete entries whose albumKey is not in activeAlbumKeys
    for cached in allCached where !activeAlbumKeys.contains(cached.albumKey) {
      modelContext.delete(cached)
    }

    try? modelContext.save()
  }
}

// MARK: - ArtworkCacheResult

/// Sendable value type returned by ``ArtworkCacheStore/fetchArtwork(forKey:)``.
public struct ArtworkCacheResult: Sendable {
  let data: Data
  let dominantColorHue: Double?
  let dominantColorSaturation: Double?
  let dominantColorBrightness: Double?
}

// MARK: - ArtworkCacheStore Container Factory

extension ArtworkCacheStore {
  /// Create a dedicated ModelContainer for artwork caching.
  /// Uses a separate SQLite file ("ArtworkCache") from the main tracks database.
  nonisolated static func makeContainer() -> ModelContainer? {
    let schema = Schema([CachedArtwork.self])
    let config = ModelConfiguration("ArtworkCache", schema: schema)
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      // Database corrupted — delete and recreate.
      let url = config.url
      try? FileManager.default.removeItem(at: url)
      let walURL = url.appendingPathExtension("wal")
      let shmURL = url.appendingPathExtension("shm")
      try? FileManager.default.removeItem(at: walURL)
      try? FileManager.default.removeItem(at: shmURL)
      return try? ModelContainer(for: schema, configurations: [config])
    }
  }
}
