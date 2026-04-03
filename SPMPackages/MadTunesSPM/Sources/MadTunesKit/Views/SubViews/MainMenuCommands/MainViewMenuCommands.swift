// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

// MARK: - MainViewMenuCommands

/// Phase 161: Extracted from MadTunesScene — View menu commands
/// (layout picker, album sort order, legacy hardware mode toggle).
struct MainViewMenuCommands: Commands {
  // MARK: Internal

  @CommandsBuilder @MainActor var body: some Commands {
    CommandGroup(before: .toolbar) {
      Picker(selection: $vm.desktopContentLayout) {
        Label {
          Text("i18n:Toolbar.ViewHGrid", bundle: #bundle)
        } icon: {
          Image(systemName: "inset.filled.topleading.bottomleading.trailinghalf.rectangle")
        }
        .tag(DesktopContentLayout.asAlbumHGrid)
        Label {
          Text("i18n:Toolbar.ViewVGrid", bundle: #bundle)
        } icon: {
          Image(systemName: "inset.filled.topleft.topright.bottomhalf.rectangle")
        }
        .tag(DesktopContentLayout.asAlbumVGrid)
        Label {
          Text("i18n:Toolbar.ViewTable", bundle: #bundle)
        } icon: {
          Image(systemName: "tablecells")
        }
        .tag(DesktopContentLayout.asTableView)
      } label: {
        Label {
          Text("i18n:Toolbar.ToggleViewLayout", bundle: #bundle)
        } icon: {
          Image(systemName: "uiwindow.split.2x1")
        }
      }
      .pickerStyle(.menu)
      if !vm.library.isImporting, vm.desktopContentLayout != .asTableView {
        Picker(selection: $vm.gridVM.albumSortOrder) {
          ForEach(AlbumSortOrder.allCases, id: \.self) { order in
            Text(order.localizedName).tag(order)
          }
        } label: {
          Label(
            String(localized: "i18n:AlbumSortMethod.Label", bundle: #bundle),
            systemImage: "arrow.up.arrow.down"
          )
        }
        .pickerStyle(.menu)
      }
      // Phase 98/161: Performance mode toggle (Intel Mac safeAreaInset expansion).
      // Moved from GlobalControlMenuCommands to MainViewMenuCommands.
      Toggle(
        isOn: Binding(
          get: { vm.gridVM.legacyHardwareMode },
          set: { vm.gridVM.legacyHardwareMode = $0 }
        )
      ) {
        Label(
          String(
            localized: "i18n:Menu.LegacyMacPerformanceMode",
            defaultValue: "Performance Mode",
            bundle: #bundle
          ),
          systemImage: "pc"
        )
      }
      Divider()
    }
  }

  // MARK: Private

  @State private var vm = MadTunesViewModel.shared
}
