// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - PlaybackEngineContextMenu

/// Phase 176: Context menu attached to every play/pause button, letting the
/// user switch the playback pipeline between AVPlayer (default) and the
/// experimental AVAudioEngine backend. Right-click on macOS, long-press on iOS.
struct PlaybackEngineContextMenu: View {
  let player: AudioPlayer

  var body: some View {
    Button {
      Task { await player.setPlaybackEngineKind(.avPlayer) }
    } label: {
      HStack {
        Text(
          String(
            localized: "i18n:PlaybackEngine.AVPlayer",
            defaultValue: "AVPlayer (Default)",
            bundle: #bundle
          )
        )
        if player.playbackEngineKind == .avPlayer {
          Spacer()
          Image(systemName: "checkmark")
        }
      }
    }
    Button {
      Task { await player.setPlaybackEngineKind(.avAudioEngine) }
    } label: {
      HStack {
        Text(
          String(
            localized: "i18n:PlaybackEngine.AVAudioEngine",
            defaultValue: "AVAudioEngine (Experimental)",
            bundle: #bundle
          )
        )
        if player.playbackEngineKind == .avAudioEngine {
          Spacer()
          Image(systemName: "checkmark")
        }
      }
    }
  }
}
