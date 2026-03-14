// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

extension Color {
  /// The MadTunes accent color, matching the values defined in the Xcode Asset Catalog.
  /// Asset Catalog AccentColor does not propagate to SwiftUI views, so we define it in code.
  /// Phase 53: When the user has explicitly set a system accent color (non-multicolor),
  /// respect that setting. Otherwise, use MadTunes' own green.
  static let madTunesAccent: Color = {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    Color(nsColor: NSColor(name: nil) { appearance in
      // AppleAccentColor is absent from UserDefaults when "Multicolor" (default) is selected.
      if UserDefaults.standard.object(forKey: "AppleAccentColor") != nil {
        return NSColor.controlAccentColor
      }
      if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        // Dark mode: R19, G198, B10.
        return NSColor(red: 0.07, green: 0.78, blue: 0.04, alpha: 1.00)
      } else {
        // Light mode: R1, G145, B14.
        return NSColor(red: 0.00, green: 0.57, blue: 0.05, alpha: 1.00)
      }
    })
    #else
    Color.accentColor
    #endif
  }()
}
