// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation
import SwiftData

// MARK: - PersistedSchemaV2

/// Phase 113: V1 (String-based IDs) removed — never shipped to App Store.
/// V2 is the production baseline: native UUID identifiers, `[UUID]` playlist track references.
enum PersistedSchemaV2: VersionedSchema {
  static let versionIdentifier: Schema.Version = .init(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [PersistedTrack.self, PersistedPlaylist.self, PersistedSourceBookmark.self]
  }
}

// MARK: - PersistedSchemaMigrationPlan

/// Phase 113: V1→V2 migration removed (V1 never reached production).
/// Retained as the central migration plan for future schema upgrades.
enum PersistedSchemaMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [PersistedSchemaV2.self]
  }

  static var stages: [MigrationStage] {
    []
  }
}
