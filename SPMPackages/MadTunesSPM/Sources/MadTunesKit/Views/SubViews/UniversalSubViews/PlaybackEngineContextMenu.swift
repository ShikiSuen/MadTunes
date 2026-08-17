// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PlaybackEngineContextMenu

/// Phase 176: Context menu attached to every play/pause button, letting the
/// user switch the playback pipeline between AVPlayer (default) and
/// AVAudioEngine. Right-click on macOS, long-press on iOS.
/// A `Picker` without an explicit style renders as a submenu when its
/// container is a context menu.
struct PlaybackEngineContextMenu: View {
  // MARK: Internal

  let player: AudioPlayer

  var body: some View {
    Picker(
      String(
        localized: "i18n:PlaybackEngine.MenuTitle",
        defaultValue: "Playback Engine",
        bundle: #bundle
      ),
      selection: engineKindBinding
    ) {
      Text(
        String(
          localized: "i18n:PlaybackEngine.AVPlayer",
          defaultValue: "AVPlayer (Default)",
          bundle: #bundle
        )
      )
      .tag(PlaybackEngineKind.avPlayer)
      Text(
        String(
          localized: "i18n:PlaybackEngine.AVAudioEngine",
          defaultValue: "AVAudioEngine",
          bundle: #bundle
        )
      )
      .tag(PlaybackEngineKind.avAudioEngine)
    }
  }

  // MARK: Private

  private var engineKindBinding: Binding<PlaybackEngineKind> {
    Binding(
      get: { player.playbackEngineKind },
      set: { newKind in
        Task { await player.setPlaybackEngineKind(newKind) }
      }
    )
  }
}
