// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

// Phase 71/72: App delegate for UIKit targets (macCatalyst only at runtime).
// - Removes "Open Recent" from File menu (not useful for a music library app).
// - Keeps the system "Open…" (CMD+O) alive and intercepts its `open:` action
//   via the responder chain, routing it to the file importer.
//   The SwiftUI side does NOT add CMD+O on macCatalyst to avoid duplicate key conflict.

#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - MadTunesAppDelegate

@MainActor
public final class MadTunesAppDelegate: UIResponder, UIApplicationDelegate {
  // MARK: - Menu Customization

  override public func buildMenu(with builder: UIMenuBuilder) {
    super.buildMenu(with: builder)
    guard builder.system == .main else { return }
    // Phase 72: Only remove "Open Recent"; keep system "Open…" (CMD+O) alive
    // so that our open(_:) handler can reuse it for file import.
    builder.remove(menu: .openRecent)
  }

  /// Ensure the system "Open…" command is always enabled.
  override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == NSSelectorFromString("open:") { return true }
    return super.canPerformAction(action, withSender: sender)
  }

  // MARK: - System Open Action Handler

  /// Intercept the system "Open…" (CMD+O) command. UIKit routes the `open:` action
  /// through the responder chain; by implementing it here the menu item becomes
  /// enabled and triggers the file importer.
  @objc
  public func open(_ sender: Any?) {
    let modifiers = ModifierKeyMonitor.shared.currentModifiers
    if modifiers.contains(.shift) {
      MadTunesViewModel.shared.isFolderImporterPresented = true
    } else {
      MadTunesViewModel.shared.isFileImporterPresented = true
    }
  }
}
#endif

// MARK: - AppKit Delegate (native macOS)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - MadTunesNSAppDelegate

/// Phase 100: AppKit delegate for native macOS. Intercepts file-open events
/// (dock icon drag-and-drop, Finder "Open With", etc.) and routes them to the
/// shared ViewModel as a single batch import, preventing SwiftUI WindowGroup
/// from creating additional windows for a single-window app.
@MainActor
public final class MadTunesNSAppDelegate: NSObject, NSApplicationDelegate {
  public func application(_ application: NSApplication, open urls: [URL]) {
    MadTunesViewModel.shared.importURLs(urls)
  }

  /// Phase 100: Single-window app — quit when the main window is closed.
  public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
#endif
