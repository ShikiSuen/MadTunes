// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import SwiftUI

extension EventModifiers: @retroactive Hashable {}

// MARK: - HotKeyHintRecord

private struct HotKeyHintRecord: Hashable, Identifiable {
  // MARK: Lifecycle

  init(
    modifiers: EventModifiers,
    keyPress: KeyEquivalent,
    keyLabel: String? = nil,
    @ArrayBuilder<String> titles: () -> [String]
  ) {
    self.modifiers = modifiers
    self.keyPress = keyPress
    self.keyLabel = keyLabel
    self.titles = titles()
  }

  // MARK: Internal

  let modifiers: EventModifiers
  let keyPress: KeyEquivalent
  let keyLabel: String?
  var titles: [String]

  var id: Int { hashValue }

  var keyCombinationString: String {
    // e.g. "⌘ + Shift + ↓" or "Space".
    let modifierSymbols: [String] = [
      (modifiers.contains(.command), "⌘"),
      (modifiers.contains(.shift), "⇧"),
      (modifiers.contains(.option), "⌥"),
      (modifiers.contains(.control), "⌃"),
      (modifiers.contains(.capsLock), "⇪"),
    ].compactMap { flag, symbol in
      flag ? symbol : nil
    }

    let keyString: String = {
      if let keyLabel {
        return keyLabel
      }

      switch keyPress {
      case .return: return "↩"
      case .space: return "␣"
      case .tab: return "⭾"
      case .delete: return "⌫"
      case .escape: return "⎋"
      case .upArrow: return "↑"
      case .downArrow: return "↓"
      case .leftArrow: return "←"
      case .rightArrow: return "→"
      case .pageUp: return "PgUp"
      case .pageDown: return "PgDn"
      case .home: return "Home"
      case .end: return "End"
      default:
        return String(keyPress.character).uppercased()
      }
    }()

    return (modifierSymbols + [keyString]).joined(separator: "")
  }
}

// MARK: - HotKeyHintView

struct HotKeyHintView: View {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var body: some View {
    Button {
      isPopoverPresented.toggle()
    } label: {
      Label(
        String(
          localized: "i18n:Toolbar.HotKeyHintView",
          defaultValue: "Hotkey Hints",
          bundle: #bundle
        ),
        systemImage: "questionmark"
      )
    }
    .tint(.primary)
    .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
      ScrollView {
        popoverContent
          .padding(12)
          .frame(minWidth: 260)
      }
    }
  }

  @ViewBuilder var popoverContent: some View {
    VStack(spacing: 4) {
      let hintsEnumerated = Array(prepareHotKeyHints().enumerated())
      let countOfHints = hintsEnumerated.count
      ForEach(hintsEnumerated, id: \.offset) { offset, hintRecord in
        drawHotKeyHint(record: hintRecord)
        if offset != countOfHints - 1 {
          Divider()
            .opacity(0.4)
        }
      }
    }
    .frame(maxWidth: 440)
  }

  // MARK: Private

  @State private var isPopoverPresented = false
  @State private var vm = MadTunesViewModel.shared

  @ViewBuilder
  private func drawHotKeyHint(record: HotKeyHintRecord) -> some View {
    LabeledContent {
      VStack(alignment: .trailing) {
        ForEach(record.titles, id: \.hashValue) { title in
          Text(verbatim: title)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.trailing)
      .frame(maxWidth: .infinity, alignment: .trailing)
    } label: {
      Text(verbatim: record.keyCombinationString)
        .padding(.horizontal, 8)
        .background(.secondary.opacity(0.2))
        .clipShape(Capsule())
        .font(.subheadline)
        .fontWidth(.standard)
    }
  }
}

extension HotKeyHintView {
  @ArrayBuilder<HotKeyHintRecord>
  private func prepareHotKeyHints() -> [HotKeyHintRecord] {
    switch vm.useTableView {
    case true:
      // ⌘↓: Play selected tracks immediately.
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: .downArrow
      ) {
        String(
          localized: "i18n:Menu.PlaySelected",
          defaultValue: "Play selected",
          bundle: #bundle
        )
      }
      // ⌘C: Copy metadata of selected tracks.
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: KeyEquivalent("c")
      ) {
        String(
          localized: "i18n:ContextMenu.CopyMetadata",
          defaultValue: "Copy metadata",
          bundle: #bundle
        )
      }
      // Return: Play selected tracks.
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .return
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.TableView.ReturnPlay",
          defaultValue: "Play selected tracks",
          bundle: #bundle
        )
      }
      // Space: Toggle play/pause (if track loaded); otherwise play selected.
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .space
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.TableView.SpaceTogglePlay",
          defaultValue: "Toggle play/pause; or play selected",
          bundle: #bundle
        )
      }
      // ⌥↑: Move selected tracks up in playlist.
      HotKeyHintRecord(
        modifiers: [.option],
        keyPress: .upArrow
      ) {
        String(
          localized: "i18n:Menu.MoveTrackUp",
          defaultValue: "Move track up",
          bundle: #bundle
        )
      }
      // ⌥↓: Move selected tracks down in playlist.
      HotKeyHintRecord(
        modifiers: [.option],
        keyPress: .downArrow
      ) {
        String(
          localized: "i18n:Menu.MoveTrackDown",
          defaultValue: "Move track down",
          bundle: #bundle
        )
      }

      if !OS.isAppKit {
        // Arrow keys: move selection up/down (UIKit List).
        HotKeyHintRecord(
          modifiers: [],
          keyPress: .upArrow
        ) {
          String(
            localized: "i18n:HotKeyHint.Record.TableView.ArrowUpDown",
            defaultValue: "Move selection",
            bundle: #bundle
          )
        }
        HotKeyHintRecord(
          modifiers: [],
          keyPress: .downArrow
        ) {
          String(
            localized: "i18n:HotKeyHint.Record.TableView.ArrowUpDown",
            defaultValue: "Move selection",
            bundle: #bundle
          )
        }
        HotKeyHintRecord(
          modifiers: [.shift],
          keyPress: .upArrow
        ) {
          String(
            localized: "i18n:HotKeyHint.Record.TableView.ShiftArrowRange",
            defaultValue: "Extend selection",
            bundle: #bundle
          )
        }
        HotKeyHintRecord(
          modifiers: [.shift],
          keyPress: .downArrow
        ) {
          String(
            localized: "i18n:HotKeyHint.Record.TableView.ShiftArrowRange",
            defaultValue: "Extend selection",
            bundle: #bundle
          )
        }
      }

      // Phase 74: PgUp/PgDn/Home/End hints.
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .pageUp,
        keyLabel: "PgUp PgDn"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.TableView.PageUpDown",
          defaultValue: "Scroll up/down by one page",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .pageUp,
        keyLabel: "PgUp PgDn"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.TableView.ShiftPageUpDown",
          defaultValue: "Range select to previous/next page",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .home,
        keyLabel: "Home End"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.TableView.HomeEnd",
          defaultValue: "Jump to first/last track",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .home,
        keyLabel: "Home End"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.TableView.ShiftHomeEnd",
          defaultValue: "Range select to first/last track",
          bundle: #bundle
        )
      }
      // ── Mouse/Pointer selection (macOS only) ──
      if OS.isAppKit {
        // ⌘ + Click: Multi-select / deselect tracks.
        HotKeyHintRecord(
          modifiers: [.command],
          keyPress: .return,
          keyLabel: String(
            localized: "i18n:HotKeyHint.KeyLabel.Click",
            defaultValue: "Click",
            bundle: #bundle
          )
        ) {
          String(
            localized: "i18n:HotKeyHint.Record.TableView.CmdClickSelect",
            defaultValue: "Multi-select/deselect tracks",
            bundle: #bundle
          )
        }
        // Shift + Click: Range select tracks.
        HotKeyHintRecord(
          modifiers: [.shift],
          keyPress: .return,
          keyLabel: String(
            localized: "i18n:HotKeyHint.KeyLabel.Click",
            defaultValue: "Click",
            bundle: #bundle
          )
        ) {
          String(
            localized: "i18n:HotKeyHint.Record.TableView.ShiftClickRangeSelect",
            defaultValue: "Range select tracks",
            bundle: #bundle
          )
        }
      }
    case false:
      // ── Commands ──
      // ⌘↓: When expanded → play selected tracks; when collapsed → expand.
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: .downArrow
      ) {
        String(
          localized: "i18n:Menu.PlayOrExpand",
          defaultValue: "Play / expand",
          bundle: #bundle
        )
      }
      // ⌘↑ / Esc: Collapse expanded album.
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: .upArrow
      ) {
        String(
          localized: "i18n:Menu.CollapseAlbum",
          defaultValue: "Collapse album",
          bundle: #bundle
        )
      }
      // Esc: Collapse expanded album (alternative).
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .escape
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.EscCollapse",
          defaultValue: "Collapse album",
          bundle: #bundle
        )
      }
      // ── Arrow key navigation (conditional behavior) ──
      // Arrow keys: move selection in album grid (left/right = adjacent, up/down = row-jump).
      // In expanded album view, if no track selected: down selects first track; up collapses.
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .upArrow,
        keyLabel: "←→↑↓"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ArrowKeys",
          defaultValue: "Move selection\n(grid: row/column; expanded: track list)",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .upArrow,
        keyLabel: "↓"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ArrowKeys.ExpandedNoSelection",
          defaultValue: "Select the first track in the album",
          bundle: #bundle
        )
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ArrowKeys.ExpandedNoSelection.Condition",
          defaultValue: "(When expanded with no track selected)",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .upArrow,
        keyLabel: "↑"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.EscCollapse",
          defaultValue: "Collapse album",
          bundle: #bundle
        )
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ArrowKeys.ExpandedNoSelection.Condition",
          defaultValue: "(When expanded with no track selected)",
          bundle: #bundle
        )
      }
      // Shift + Arrow keys: Range select albums (anchor-based).
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .upArrow,
        keyLabel: "  ←→↑↓"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ShiftArrowRangeSelect",
          defaultValue: "Range select albums (anchor-based)",
          bundle: #bundle
        )
      }
      // Phase 74: PgUp/PgDn/Home/End for grid.
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .pageUp,
        keyLabel: "PgUp PgDn"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.PageUpDown",
          defaultValue: "Scroll up/down by one page",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .pageUp,
        keyLabel: "PgUp PgDn"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ShiftPageUpDown",
          defaultValue: "Range select to previous/next page",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .home,
        keyLabel: "Home End"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.HomeEnd",
          defaultValue: "Jump to first/last album",
          bundle: #bundle
        )
      }
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .home,
        keyLabel: "Home End"
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ShiftHomeEnd",
          defaultValue: "Range select to first/last album",
          bundle: #bundle
        )
      }
      // ⌘A: Select all albums (no expansion) or all tracks (in expanded album).
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: KeyEquivalent("a")
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.SelectAll",
          defaultValue: "Select all albums / tracks",
          bundle: #bundle
        )
      }
      // ⌘C: Copy metadata (requires expanded album + selected tracks).
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: KeyEquivalent("c")
      ) {
        String(
          localized: "i18n:ContextMenu.CopyMetadata",
          defaultValue: "Copy metadata",
          bundle: #bundle
        )
      }
      // Return: Expand album / play selected tracks.
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .return
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ReturnExpand",
          defaultValue: "Expand album / play selected tracks",
          bundle: #bundle
        )
      }
      // ── Space (swap based on expanded state) ──
      let spaceHint: String
      let shiftSpaceHint: String
      if vm.gridVM.expandedAlbumID != nil {
        spaceHint = String(
          localized: "i18n:HotKeyHint.Record.GridView.SpaceExpanded",
          defaultValue: "Toggle play/pause (when expanded)",
          bundle: #bundle
        )
        shiftSpaceHint = String(
          localized: "i18n:HotKeyHint.Record.GridView.ShiftSpaceExpanded",
          defaultValue: "Play selected / collapse (when expanded)",
          bundle: #bundle
        )
      } else {
        spaceHint = String(
          localized: "i18n:HotKeyHint.Record.GridView.SpaceNotExpanded",
          defaultValue: "Expand album (when collapsed)",
          bundle: #bundle
        )
        shiftSpaceHint = String(
          localized: "i18n:HotKeyHint.Record.GridView.ShiftSpaceNotExpanded",
          defaultValue: "Toggle play/pause (when collapsed)",
          bundle: #bundle
        )
      }

      HotKeyHintRecord(
        modifiers: [],
        keyPress: .space
      ) {
        spaceHint
      }
      // ── Shift+Space (swap based on expanded state) ──
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .space
      ) {
        shiftSpaceHint
      }
      // ── Mouse/Pointer selection ──
      // ⌘ + Click: Multi-select / deselect albums (expanded: tracks).
      HotKeyHintRecord(
        modifiers: [.command],
        keyPress: .return,
        keyLabel: String(
          localized: "i18n:HotKeyHint.KeyLabel.Click",
          defaultValue: "Click",
          bundle: #bundle
        )
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.CmdClickSelect",
          defaultValue: "Multi-select/deselect albums (expanded: tracks)",
          bundle: #bundle
        )
      }
      // Shift + Click: Range select albums (expanded: range select tracks).
      HotKeyHintRecord(
        modifiers: [.shift],
        keyPress: .return,
        keyLabel: String(
          localized: "i18n:HotKeyHint.KeyLabel.Click",
          defaultValue: "Click",
          bundle: #bundle
        )
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.ShiftClickRangeSelect",
          defaultValue: "Range select albums (expanded: range select tracks)",
          bundle: #bundle
        )
      }
      // Drag selection: Rubber-band select multiple albums (hold ⌘ to append).
      HotKeyHintRecord(
        modifiers: [],
        keyPress: .return,
        keyLabel: String(
          localized: "i18n:HotKeyHint.KeyLabel.DragSelection",
          defaultValue: "Drag selection",
          bundle: #bundle
        )
      ) {
        String(
          localized: "i18n:HotKeyHint.Record.GridView.DragSelectAlbums",
          defaultValue: "Rubber-band select multiple albums (hold ⌘ to append)",
          bundle: #bundle
        )
        String(
          localized: "i18n:HotKeyHint.Record.GridView.DragSelectAlbums.Condition",
          defaultValue: "(Only effective when no album is expanded)\n(Tap the grid gaps to initiate the Rubber-band selection)",
          bundle: #bundle
        )
      }
    }
  }
}
