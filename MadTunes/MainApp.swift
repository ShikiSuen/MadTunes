// (c) 2025 and onwards Shiki Suen (AGPL v3.0 License or later).
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
  var body: some Scene {
    MadTunesScene()
  }
}
