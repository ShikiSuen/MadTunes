// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

/// 播放清單類型，用於區分系統、靜態和動態播放清單。
public enum PlaylistKind: String, Sendable, Codable, CaseIterable {
  /// 系統播放清單（不可刪除）：「All Music」、「♥ Favorites」
  case system
  /// 使用者手動管理的靜態播放清單
  case staticList
  /// 述詞驅動的動態播放清單
  case dynamicList
  /// Phase 129: 資料夾播放清單，曲目來自指定資料夾
  case folderList

  // MARK: Public

  public var localizedDescription: String {
    switch self {
    // 系統播放清單
    case .system: String(localized: "i18n:PlaylistKind.system", bundle: #bundle)
    // 靜態播放清單
    case .staticList: String(localized: "i18n:PlaylistKind.staticList", bundle: #bundle)
    // 動態播放清單
    case .dynamicList: String(localized: "i18n:PlaylistKind.dynamicList", bundle: #bundle)
    // 資料夾播放清單
    case .folderList: String(localized: "i18n:PlaylistKind.folderList", bundle: #bundle)
    }
  }
}
