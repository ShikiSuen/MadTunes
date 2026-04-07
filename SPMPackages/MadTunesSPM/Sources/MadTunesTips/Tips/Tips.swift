// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI
@_exported import TipKit

// MARK: - Tip4AudioOutputDeviceSelection

package struct Tip4AudioOutputDeviceSelection: Tip {
  package static let shared = Self()

  package var title: Text {
    Text("i18n.Tips.Tip4AudioOutputDeviceSelection.headerTitle", bundle: #bundle)
  }

  package var message: Text? {
    Text("i18n.Tips.Tip4AudioOutputDeviceSelection.msg", bundle: #bundle)
  }

  package var image: Image? {
    Image(systemName: "hifispeaker.2")
  }
}

// MARK: - Tip4ColumnBrowser

package struct Tip4ColumnBrowser: Tip {
  package static let shared = Self()

  package var title: Text {
    Text("i18n.Tips.Tip4ColumnBrowser.headerTitle", bundle: #bundle)
  }

  package var message: Text? {
    Text("i18n.Tips.Tip4ColumnBrowser.msg", bundle: #bundle)
  }

  package var image: Image? {
    Image(systemName: "line.3.horizontal.decrease")
  }
}

// MARK: - Tip4GridLayout

package struct Tip4GridLayout: Tip {
  package static let shared = Self()

  package var title: Text {
    Text("i18n.Tips.Tip4GridLayout.headerTitle", bundle: #bundle)
  }

  package var message: Text? {
    Text("i18n.Tips.Tip4GridLayout.msg", bundle: #bundle)
  }

  package var image: Image? {
    Image(systemName: "square.grid.3x2")
  }
}

// MARK: - Tip4NonStaticPlaylists

package struct Tip4NonStaticPlaylists: Tip {
  package static let shared = Self()

  package var title: Text {
    Text("i18n.Tips.Tip4NonStaticPlaylists.headerTitle", bundle: #bundle)
  }

  package var message: Text? {
    Text("i18n.Tips.Tip4NonStaticPlaylists.msg", bundle: #bundle)
  }

  package var image: Image? {
    Image(systemName: "music.note.list")
  }
}
