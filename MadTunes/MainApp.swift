// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import MadTunesKit
import SwiftUI

// MARK: - MainEntry

@main
struct MainEntry {
  static func main() {
    MadTunesApp.main()
  }
}

// MARK: - MadTunesApp

struct MadTunesApp: App {
  // Phase 71: UIKit app delegate to customize the File menu (remove system Open/Open Recent).
  #if canImport(UIKit)
  @UIApplicationDelegateAdaptor(MadTunesAppDelegate.self) var delegate
  #endif

  var body: some Scene {
    MadTunesScene()
  }
}
