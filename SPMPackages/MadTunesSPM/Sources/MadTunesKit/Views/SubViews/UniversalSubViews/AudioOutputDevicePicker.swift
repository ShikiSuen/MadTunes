// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

#if os(macOS)

import SwiftUI

// MARK: - AudioOutputDevicePicker

/// Phase 177: Picker-style audio output device menu (macOS only).
/// The system automatically marks the currently selected device with a
/// checkmark — replacing the previous hand-rolled `Button` rows with manual
/// checkmark images, whose alignment the menu's layout constraints made
/// unreliable (the selection was effectively invisible).
/// Embed inside a plain `Menu` with `.pickerStyle(.inline)` for a toolbar /
/// player-bar button (pass an `EmptyView` label), or place directly in a
/// `CommandMenu` with `.pickerStyle(.menu)` to render as a submenu in the
/// menu bar (pass a `Label` describing the section).
struct AudioOutputDevicePicker<Label: View>: View {
  // MARK: Lifecycle

  init(player: AudioPlayer, @ViewBuilder label: @escaping () -> Label) {
    self.player = player
    self.label = label
  }

  // MARK: Internal

  var body: some View {
    Picker(selection: outputDeviceBinding) {
      Text(
        String(
          localized: "i18n:AudioOutput.SystemDefault",
          defaultValue: "System Default",
          bundle: #bundle
        )
      )
      .tag(String?.none)
      Divider()
      ForEach(player.outputDeviceManager.outputDevices) { device in
        outputDeviceRow(device)
          .tag(device.uid as String?)
      }
    } label: {
      label()
    }
  }

  // MARK: Private

  private let player: AudioPlayer
  private let label: () -> Label

  private var outputDeviceBinding: Binding<String?> {
    Binding(
      get: { player.outputDeviceManager.selectedDeviceUID },
      set: { player.setOutputDevice(uid: $0) }
    )
  }

  @ViewBuilder
  private func outputDeviceRow(_ device: AudioOutputDevice) -> some View {
    HStack(spacing: 4) {
      Text(verbatim: device.name)
      if device.uid == player.outputDeviceManager.cachedSystemDefaultDeviceUID {
        Text(verbatim: "⌂").foregroundStyle(.secondary)
      }
    }
  }
}

#endif
