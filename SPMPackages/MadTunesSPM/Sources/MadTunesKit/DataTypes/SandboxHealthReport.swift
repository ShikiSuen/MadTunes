// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

// Phase 158: Captures sandbox bookmark resolution health at app launch.

import Foundation

// MARK: - SandboxHealthReport

public struct SandboxHealthReport: Sendable {
  public enum Severity: Sendable, Equatable {
    case healthy, warning, critical
  }

  public var totalSourceBookmarks: Int = 0
  public var failedSourceBookmarks: Int = 0
  public var totalFolderPlaylists: Int = 0
  public var failedFolderPlaylists: Int = 0
  public var failedFolderPlaylistIDs: Set<UUID> = []

  public var hasAnyFailure: Bool {
    failedSourceBookmarks > 0 || failedFolderPlaylists > 0
  }

  public var severity: Severity {
    if failedSourceBookmarks == totalSourceBookmarks, totalSourceBookmarks > 0 {
      return .critical
    }
    if failedSourceBookmarks > 0 || failedFolderPlaylists > 0 {
      return .warning
    }
    return .healthy
  }
}

// MARK: - SandboxReapprovalReport

/// Phase 164: Result of a reapprove-sandbox-privileges operation.
public struct SandboxReapprovalReport: Sendable {
  public var checkedTrackCount: Int = 0
  public var refreshedTrackCount: Int = 0
  public var checkedFolderPlaylistCount: Int = 0
  public var refreshedFolderPlaylistCount: Int = 0

  public var totalChecked: Int { checkedTrackCount + checkedFolderPlaylistCount }
  public var totalRefreshed: Int { refreshedTrackCount + refreshedFolderPlaylistCount }
}

// MARK: - PlaybackError

/// Phase 158: Structured playback error for UI display.
public enum PlaybackError: Sendable, Equatable {
  case fileNotReadable(title: String)
  case bookmarkResolutionFailed(title: String)
  case securityScopeAccessDenied(title: String)
  case avPlayerFailed(title: String)

  // MARK: Public

  public var localizedMessage: String {
    switch self {
    case let .fileNotReadable(title):
      return String(
        localized: "i18n:PlaybackError.FileNotReadable:\(title)",
        bundle: #bundle
      )
    case let .bookmarkResolutionFailed(title):
      return String(
        localized: "i18n:PlaybackError.BookmarkFailed:\(title)",
        bundle: #bundle
      )
    case let .securityScopeAccessDenied(title):
      return String(
        localized: "i18n:PlaybackError.AccessDenied:\(title)",
        bundle: #bundle
      )
    case let .avPlayerFailed(title):
      return String(
        localized: "i18n:PlaybackError.PlayerFailed:\(title)",
        bundle: #bundle
      )
    }
  }
}
