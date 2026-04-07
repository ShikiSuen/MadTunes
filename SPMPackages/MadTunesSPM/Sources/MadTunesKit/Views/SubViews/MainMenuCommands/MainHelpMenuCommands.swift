// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
import TipKit

// MARK: - MainViewMenuCommands

/// Phase 161: Extracted from MadTunesScene — View menu commands
/// (layout picker, album sort order, legacy hardware mode toggle).
struct MainHelpMenuCommands: Commands {
  // MARK: Internal

  @CommandsBuilder @MainActor var body: some Commands {
    CommandGroup(before: .help) {
      Button {
        resetTipsOnNextStartup = true
        vm.showResetTipsScheduledAlert = true
      } label: {
        Label(
          String(localized: "i18n:MainMenu.Help.resetTutorialTips", bundle: #bundle),
          systemImage: "lightbulb.min.badge.exclamationmark"
        )
      }
    }
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared

  @AppStorage(wrappedValue: false, "MadTunes.resetTipsOnNextStartup") private var resetTipsOnNextStartup: Bool
}
